import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../logger.dart';
import '../services/file_times_apply.dart';
import '../services/mtime_util.dart';
import '../services/receive_dir_resolver.dart';
import 'signaling_channel.dart';

const _iceTimeoutMs = 15000;
const _chunkSize = 16 * 1024;
const _highWaterMark = 1024 * 1024;
const _lowWaterMark = 256 * 1024;
const _maxInFlightBytes = 4 * 1024 * 1024;

typedef OnFileProgress = void Function(String fileId, int received, int total);
typedef OnFileReceived =
    void Function(String fileId, String fileName, String filePath);
typedef OnFileSent = void Function(String fileId, String fileName);
typedef OnFileFailed =
    void Function(String fileId, String fileName, String error);
typedef OnFileCancelled = void Function(String fileId, String fileName);
typedef OnSessionStateChange = void Function(String sessionId, String state);

class WebRTCSession {
  final String sessionId;
  final String remoteDeviceId;
  final String localDeviceId;

  RTCPeerConnection? _pc;
  RTCDataChannel? _controlChannel;
  final Map<String, RTCDataChannel> _fileChannels = {};
  final Map<String, Completer<void>> _fileChannelOpenCompleters = {};
  final List<RTCIceCandidate> _iceCandidateBuffer = [];
  bool _remoteDescriptionSet = false;
  bool _sendingStarted = false;
  Timer? _connectionTimer;
  Timer? _disconnectTimer;

  final List<PendingSend> _pendingSends = [];
  final Map<String, _ReceiveState> _receiveStates = {};
  final Map<String, Completer<void>> _fileAckCompleters = {};
  final Map<String, int> _receiverConfirmed = {};
  final Map<String, Completer<void>> _flowControlWaiters = {};
  final Map<String, int> _resumeOffsets = {};
  final Map<String, Completer<int>> _resumeWaiters = {};

  /// Files that the local user explicitly cancelled (per fileId). Used by
  /// `_sendSingleFile` to route the resulting channel-close exception to the
  /// `onFileCancelled` callback instead of `onFileFailed`, keeping bubble
  /// status, retry UI and analytics consistent with the user's intent.
  final Set<String> _locallyCancelledFiles = {};

  OnFileProgress? onProgress;
  OnFileReceived? onFileReceived;
  OnFileSent? onFileSent;
  OnFileFailed? onFileFailed;
  OnFileCancelled? onFileCancelled;
  OnSessionStateChange? onStateChange;

  bool _cancelledByRemote = false;

  final Completer<void> _connectedCompleter = Completer<void>();
  Future<void> get connected => _connectedCompleter.future;

  String? saveDirPath;

  WebRTCSession({
    required this.sessionId,
    required this.remoteDeviceId,
    required this.localDeviceId,
    this.saveDirPath,
  });

  Future<String> _dirForIncomingFiles() async {
    final configured = saveDirPath;
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return ReceiveDirResolver.fallbackReceiveRootPath();
  }

  Future<void> _initPeerConnection() async {
    final config = <String, dynamic>{
      'iceServers': <Map<String, dynamic>>[
        {'urls': 'stun:stun.miwifi.com:3478'},
        {'urls': 'stun:stun.qq.com:3478'},
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    _pc = await createPeerConnection(config);

    _pc!.onIceCandidate = (candidate) {
      sendWebRTCSignal({
        'type': 'webrtc_ice_candidate',
        'sessionId': sessionId,
        'senderDeviceId': localDeviceId,
        'targetDeviceId': remoteDeviceId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      }).catchError((e) => logChat.warning('sendIceCandidate failed: $e'));
    };

    _pc!.onConnectionState = (state) {
      logChat.info('WebRTC connectionState=$state session=$sessionId');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _clearConnectionTimer();
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
        onStateChange?.call(sessionId, 'connected');
        if (!_connectedCompleter.isCompleted) _connectedCompleter.complete();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _clearConnectionTimer();
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
        onStateChange?.call(sessionId, 'failed');
        if (!_connectedCompleter.isCompleted) {
          _connectedCompleter.completeError(Exception('Connection $state'));
        }
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onStateChange?.call(sessionId, 'disconnected');
        // Start a timer: if connection doesn't recover within 5s, treat as failed.
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 5), () {
          logChat.warning(
            'WebRTC disconnected for 5s, treating as failed session=$sessionId',
          );
          onStateChange?.call(sessionId, 'failed');
          // close() will shut down all data channels, which triggers
          // channelClosed errors in any active _sendSingleFile calls,
          // causing them to call onFileFailed via their catch blocks.
          close();
        });
      }
    };

    _pc!.onDataChannel = (channel) {
      logChat.info('onDataChannel label=${channel.label}');
      if (channel.label == 'control') {
        _controlChannel = channel;
        _setupControlChannel(channel);
      } else if (channel.label!.startsWith('file-')) {
        final fileId = channel.label!.substring(5);
        _fileChannels[fileId] = channel;
        _setupFileReceiveChannel(channel, fileId);
      }
    };
  }

  void _startConnectionTimer() {
    _connectionTimer = Timer(const Duration(milliseconds: _iceTimeoutMs), () {
      if (!_connectedCompleter.isCompleted) {
        logChat.warning('ICE timeout session=$sessionId');
        onStateChange?.call(sessionId, 'failed');
        _connectedCompleter.completeError(Exception('ICE connection timeout'));
        close();
      }
    });
  }

  void _clearConnectionTimer() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

  Future<void> createOffer(List<PendingSend> files) async {
    _pendingSends.addAll(files);
    onStateChange?.call(sessionId, 'connecting');
    await _initPeerConnection();

    final dcInit = RTCDataChannelInit()..ordered = true;
    _controlChannel = await _pc!.createDataChannel('control', dcInit);
    _setupControlChannel(_controlChannel!);

    for (final f in files) {
      final dc = await _pc!.createDataChannel('file-${f.meta.fileId}', dcInit);
      _fileChannels[f.meta.fileId] = dc;
      _setupSenderFileChannel(dc, f.meta.fileId);
    }

    final offer = await _pc!.createOffer({});
    await _pc!.setLocalDescription(offer);
    _remoteDescriptionSet = false;

    await sendWebRTCSignal({
      'type': 'webrtc_offer',
      'sessionId': sessionId,
      'senderDeviceId': localDeviceId,
      'targetDeviceId': remoteDeviceId,
      'sdp': offer.sdp,
      'files': files.map((f) => f.meta.toJson()).toList(),
    });

    _startConnectionTimer();
  }

  Future<void> handleOffer(Map<String, dynamic> signal) async {
    onStateChange?.call(sessionId, 'connecting');
    await _initPeerConnection();

    final filesRaw = signal['files'] as List? ?? [];
    for (final f in filesRaw) {
      if (f is Map<String, dynamic>) {
        final meta = WebRTCFileMeta.fromJson(f);
        _receiveStates[meta.fileId] = _ReceiveState(meta: meta);
      }
    }

    final sdp = signal['sdp'] as String;
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    _remoteDescriptionSet = true;
    await _flushIceCandidateBuffer();

    final answer = await _pc!.createAnswer({});
    await _pc!.setLocalDescription(answer);

    await sendWebRTCSignal({
      'type': 'webrtc_answer',
      'sessionId': sessionId,
      'senderDeviceId': localDeviceId,
      'targetDeviceId': remoteDeviceId,
      'sdp': answer.sdp,
    });

    _startConnectionTimer();
  }

  Future<void> handleAnswer(Map<String, dynamic> signal) async {
    final sdp = signal['sdp'] as String;
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    _remoteDescriptionSet = true;
    await _flushIceCandidateBuffer();
  }

  Future<void> handleIceCandidate(Map<String, dynamic> signal) async {
    final candidateMap = signal['candidate'] as Map<String, dynamic>;
    final candidate = RTCIceCandidate(
      candidateMap['candidate'] as String?,
      candidateMap['sdpMid'] as String?,
      candidateMap['sdpMLineIndex'] as int?,
    );
    if (_remoteDescriptionSet) {
      await _pc!.addCandidate(candidate);
    } else {
      _iceCandidateBuffer.add(candidate);
    }
  }

  void handleTransferCancel() {
    logChat.info('transfer cancelled by remote session=$sessionId');
    _cancelledByRemote = true;
    for (final entry in _receiveStates.entries) {
      onFileCancelled?.call(entry.key, entry.value.meta.fileName);
    }
    _receiveStates.clear();
    close();
  }

  /// Cancel one file inside this session. Sends a `file_cancel` control
  /// message to the remote so the receiver mirrors the state, then closes
  /// just the file's data channel (the session itself keeps running).
  void cancelFile(String fileId) {
    final isPending = _pendingSends.any((p) => p.meta.fileId == fileId);
    final isReceiving = _receiveStates.containsKey(fileId);
    if (!isPending && !isReceiving) return;
    logChat.info('cancelFile fileId=$fileId session=$sessionId');
    _locallyCancelledFiles.add(fileId);

    _sendControlMessage({'type': 'file_cancel', 'fileId': fileId});

    // Wake up any waiters blocked on this file so the sender loop exits
    // promptly rather than waiting for the 30s flow-control timeout.
    final flowWaiter = _flowControlWaiters.remove(fileId);
    if (flowWaiter != null && !flowWaiter.isCompleted) {
      flowWaiter.completeError(Exception('Cancelled'));
    }
    final ackWaiter = _fileAckCompleters.remove(fileId);
    if (ackWaiter != null && !ackWaiter.isCompleted) {
      ackWaiter.completeError(Exception('Cancelled'));
    }

    // Receiver side: surface cancel to the UI and keep the partial on disk
    // for resume.
    final state = _receiveStates.remove(fileId);
    if (state != null) {
      unawaited(_flushPartialToDisk(fileId, state));
      onFileCancelled?.call(fileId, state.meta.fileName);
    }

    // Drop any pending (not-yet-started) send for this fileId so the queue
    // doesn't try to start it later.
    _pendingSends.removeWhere((p) => p.meta.fileId == fileId);

    final dc = _fileChannels.remove(fileId);
    dc?.close();
  }

  Future<void> _flushIceCandidateBuffer() async {
    for (final c in _iceCandidateBuffer) {
      await _pc!.addCandidate(c);
    }
    _iceCandidateBuffer.clear();
  }

  void _setupControlChannel(RTCDataChannel dc) {
    dc.onDataChannelState = (state) {
      logChat.info('control channel state=$state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _tryStartSending();
      }
    };
    dc.onMessage = (msg) {
      try {
        final data = jsonDecode(msg.text) as Map<String, dynamic>;
        _handleControlMessage(data);
      } catch (e) {
        logChat.warning('control message parse error: $e');
      }
    };
    if (dc.state == RTCDataChannelState.RTCDataChannelOpen) {
      _tryStartSending();
    }
  }

  void _tryStartSending() {
    if (_sendingStarted || _pendingSends.isEmpty) return;
    _sendingStarted = true;
    logChat.info('starting file sends (${_pendingSends.length} files)');
    _startSendingFiles();
  }

  void _setupSenderFileChannel(RTCDataChannel dc, String fileId) {
    final completer = Completer<void>();
    _fileChannelOpenCompleters[fileId] = completer;
    dc.onDataChannelState = (state) {
      logChat.info('sender file channel state=$state fileId=$fileId');
      if (state == RTCDataChannelState.RTCDataChannelOpen &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    if (dc.state == RTCDataChannelState.RTCDataChannelOpen &&
        !completer.isCompleted) {
      completer.complete();
    }
  }

  void _handleControlMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    final fileId = msg['fileId'] as String?;

    switch (type) {
      case 'file_start':
        if (fileId != null) {
          if (!_receiveStates.containsKey(fileId)) {
            final rawLocalId = msg['localId'];
            final senderLocalId =
                (rawLocalId is String && rawLocalId.isNotEmpty)
                ? rawLocalId
                : null;
            final meta = WebRTCFileMeta(
              fileId: fileId,
              fileName: msg['fileName'] as String? ?? 'unknown',
              fileSize: msg['fileSize'] as int? ?? 0,
              mimeType:
                  msg['mimeType'] as String? ?? 'application/octet-stream',
              lastModifiedMs: parseMtimeMs(msg['lastModifiedMs']),
              senderLocalId: senderLocalId,
            );
            _receiveStates[fileId] = _ReceiveState(meta: meta);
          }
          final state = _receiveStates[fileId]!;
          if (!state.resumeRequested) {
            _checkAndRequestResume(fileId, state.meta);
          }
        }
        break;
      case 'file_end':
        if (fileId != null) {
          final state = _receiveStates[fileId];
          if (state != null) {
            if (state.received >= state.meta.fileSize) {
              _receiveStates.remove(fileId);
              _finalizeReceivedFile(fileId, state);
            } else {
              logChat.info(
                'file_end received but data incomplete: ${state.received}/${state.meta.fileSize}, deferring finalize',
              );
              state.pendingFinalize = true;
            }
          }
        }
        break;
      case 'file_ack':
        logChat.info('file_ack fileId=$fileId success=${msg['success']}');
        final ackCompleter = _fileAckCompleters.remove(fileId);
        if (ackCompleter != null && !ackCompleter.isCompleted) {
          ackCompleter.complete();
        }
        break;
      case 'progress':
        if (fileId != null) {
          _receiverConfirmed[fileId] = msg['received'] as int? ?? 0;
          final waiter = _flowControlWaiters.remove(fileId);
          if (waiter != null && !waiter.isCompleted) {
            waiter.complete();
          }
        }
        logChat.fine(
          'receiver progress fileId=$fileId received=${msg['received']}',
        );
        break;
      case 'file_resume_request':
        if (fileId != null) {
          final receivedBytes = msg['receivedBytes'] as int? ?? 0;
          logChat.info(
            'file_resume_request fileId=$fileId receivedBytes=$receivedBytes',
          );
          _resumeOffsets[fileId] = receivedBytes;
          _sendControlMessage({
            'type': 'file_resume_accept',
            'fileId': fileId,
            'offset': receivedBytes,
          });
          final waiter = _resumeWaiters.remove(fileId);
          if (waiter != null && !waiter.isCompleted) {
            waiter.complete(receivedBytes);
          }
        }
        break;
      case 'file_resume_accept':
        if (fileId != null) {
          final offset = msg['offset'] as int? ?? 0;
          logChat.info('file_resume_accept fileId=$fileId offset=$offset');
          _resumeOffsets[fileId] = offset;
          final state = _receiveStates[fileId];
          if (state != null) {
            state.resumeConfirmed = true;
          }
        }
        break;
      case 'session_complete':
        logChat.info('session complete');
        break;
      case 'file_cancel':
        // Single-file cancel from the sender. Drop only the targeted receive
        // state; keep the partial file on disk so a later retry can resume.
        if (fileId != null) {
          logChat.info('file_cancel received fileId=$fileId');
          final state = _receiveStates.remove(fileId);
          final waiter = _flowControlWaiters.remove(fileId);
          if (waiter != null && !waiter.isCompleted) {
            waiter.complete();
          }
          // Best-effort flush so the next attempt can resume from where we
          // stopped.
          if (state != null) {
            unawaited(_flushPartialToDisk(fileId, state));
            onFileCancelled?.call(fileId, state.meta.fileName);
          }
          // Close just this file's data channel; the control channel stays
          // open so the rest of the session can keep running.
          final dc = _fileChannels.remove(fileId);
          dc?.close();
        }
        break;
    }
  }

  void _sendControlMessage(Map<String, dynamic> msg) {
    if (_controlChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      final text = RTCDataChannelMessage(jsonEncode(msg));
      _controlChannel!.send(text);
    }
  }

  Future<void> _startSendingFiles() async {
    try {
      const maxConcurrent = 4;
      final queue = List<PendingSend>.from(_pendingSends);
      var running = 0;
      final allDone = Completer<void>();

      void startNext() {
        while (running < maxConcurrent && queue.isNotEmpty) {
          final pending = queue.removeAt(0);
          running++;
          _sendSingleFile(pending)
              .catchError((e) {
                logChat.warning('sendSingleFile failed: $e');
              })
              .whenComplete(() {
                running--;
                if (queue.isEmpty && running == 0) {
                  if (!allDone.isCompleted) allDone.complete();
                } else {
                  startNext();
                }
              });
        }
        if (queue.isEmpty && running == 0 && !allDone.isCompleted) {
          allDone.complete();
        }
      }

      startNext();
      await allDone.future;
      _sendControlMessage({'type': 'session_complete'});
    } catch (e) {
      logChat.warning('_startSendingFiles error: $e');
    }
  }

  Future<void> _sendSingleFile(PendingSend pending) async {
    final meta = pending.meta;

    try {
      logChat.info(
        'sendSingleFile start fileId=${meta.fileId} name=${meta.fileName} path=${pending.filePath}',
      );

      _sendControlMessage({
        'type': 'file_start',
        'fileId': meta.fileId,
        'fileName': meta.fileName,
        'fileSize': meta.fileSize,
        'mimeType': meta.mimeType,
        if (meta.lastModifiedMs != null) 'lastModifiedMs': meta.lastModifiedMs,
        if (meta.senderLocalId != null) 'localId': meta.senderLocalId,
      });

      final dc = _fileChannels[meta.fileId];
      if (dc == null) {
        throw Exception('File DataChannel not found for fileId=${meta.fileId}');
      }

      final openCompleter = _fileChannelOpenCompleters[meta.fileId];
      if (openCompleter != null && !openCompleter.isCompleted) {
        await openCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception(
              'File DataChannel open timeout fileId=${meta.fileId}',
            );
          },
        );
      }

      logChat.info(
        'file channel ready, state=${dc.state} fileId=${meta.fileId}',
      );

      final file = File(pending.filePath);
      if (!await file.exists()) {
        throw Exception('File not found: ${pending.filePath}');
      }
      final fileSize = await file.length();
      logChat.info('sendSingleFile reading file size=$fileSize');

      // Wait for a possible resume request from the receiver.
      // The receiver needs time to check for a partial file on disk and send
      // file_resume_request back through the control channel.
      int offset = 0;
      if (!_resumeWaiters.containsKey(meta.fileId)) {
        final waiter = Completer<int>();
        _resumeWaiters[meta.fileId] = waiter;
        try {
          offset = await waiter.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => 0,
          );
        } catch (_) {
          offset = 0;
        }
        _resumeWaiters.remove(meta.fileId);
      }
      offset = _resumeOffsets[meta.fileId] ?? offset;
      if (offset > 0) {
        logChat.info('WebRTC resume from offset=$offset fileId=${meta.fileId}');
      }

      dc.bufferedAmountLowThreshold = _lowWaterMark;
      Completer<void>? drainCompleter;
      bool channelClosed = false;
      bool useTimePacing = false;

      dc.onBufferedAmountLow = (amount) {
        if (drainCompleter != null && !drainCompleter.isCompleted) {
          drainCompleter.complete();
        }
      };
      dc.onDataChannelState = (state) {
        logChat.info('file channel state=$state fileId=${meta.fileId}');
        if (state != RTCDataChannelState.RTCDataChannelOpen) {
          channelClosed = true;
          if (drainCompleter != null && !drainCompleter.isCompleted) {
            drainCompleter.completeError(Exception('DataChannel closed'));
          }
          final waiter = _flowControlWaiters.remove(meta.fileId);
          if (waiter != null && !waiter.isCompleted) {
            waiter.completeError(Exception('DataChannel closed'));
          }
        }
      };

      int chunkCount = 0;
      final stream = file.openRead(offset);
      await for (final chunk in stream) {
        if (channelClosed) {
          throw Exception('DataChannel closed during send');
        }
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);

        int pos = 0;
        while (pos < bytes.length) {
          final end = (pos + _chunkSize).clamp(0, bytes.length);
          final slice = bytes.sublist(pos, end);

          dc.send(RTCDataChannelMessage.fromBinary(slice));
          offset += slice.length;
          chunkCount++;
          pos = end;

          if (chunkCount % 4 == 0) {
            if (useTimePacing) {
              await Future.delayed(const Duration(milliseconds: 2));
            } else {
              await Future.delayed(Duration.zero);
            }

            if (!useTimePacing && chunkCount == 16 && offset > 0) {
              final buffered = dc.bufferedAmount;
              if (buffered == null || buffered == 0) {
                useTimePacing = true;
                logChat.info(
                  'bufferedAmount not available, switching to time-based pacing',
                );
              }
            }

            // 本地 bufferedAmount 背压（管理本地发送缓冲区）
            if (!useTimePacing) {
              final buffered = dc.bufferedAmount;
              if (buffered != null && buffered > _highWaterMark) {
                logChat.info('backpressure: pausing send, buffered=$buffered');
                drainCompleter = Completer<void>();

                final pollTimer = Timer.periodic(
                  const Duration(milliseconds: 50),
                  (timer) {
                    final b = dc.bufferedAmount;
                    if (b == null ||
                        b <= _lowWaterMark ||
                        dc.state != RTCDataChannelState.RTCDataChannelOpen) {
                      timer.cancel();
                      if (drainCompleter != null &&
                          !drainCompleter.isCompleted) {
                        drainCompleter.complete();
                      }
                    }
                  },
                );

                try {
                  await drainCompleter.future.timeout(
                    const Duration(seconds: 30),
                    onTimeout: () {
                      throw Exception(
                        'Buffer drain timeout fileId=${meta.fileId}',
                      );
                    },
                  );
                } finally {
                  pollTimer.cancel();
                }
                logChat.info(
                  'backpressure: resumed, buffered=${dc.bufferedAmount}',
                );
              }
            }

            // 端到端流控：限制在途数据量，防止远端 SCTP 缓冲区溢出
            final confirmed = _receiverConfirmed[meta.fileId] ?? 0;
            final inFlight = offset - confirmed;
            if (inFlight > _maxInFlightBytes) {
              logChat.info(
                'flow control: pausing, sent=$offset confirmed=$confirmed inFlight=$inFlight',
              );
              final waiter = Completer<void>();
              _flowControlWaiters[meta.fileId] = waiter;
              try {
                await waiter.future.timeout(
                  const Duration(seconds: 30),
                  onTimeout: () {
                    logChat.warning(
                      'flow control: timeout fileId=${meta.fileId}',
                    );
                    throw Exception(
                      'Flow control timeout - receiver likely disconnected',
                    );
                  },
                );
              } catch (e) {
                _flowControlWaiters.remove(meta.fileId);
                if (channelClosed ||
                    dc.state != RTCDataChannelState.RTCDataChannelOpen) {
                  throw Exception(
                    'DataChannel closed during flow control wait',
                  );
                }
                rethrow;
              }
              logChat.info(
                'flow control: resumed, confirmed=${_receiverConfirmed[meta.fileId] ?? 0}',
              );
            }

            if (channelClosed ||
                dc.state != RTCDataChannelState.RTCDataChannelOpen) {
              throw Exception('DataChannel closed during send');
            }

            onProgress?.call(meta.fileId, offset, fileSize);
          }
        }
      }
      onProgress?.call(meta.fileId, offset, fileSize);

      _sendControlMessage({'type': 'file_end', 'fileId': meta.fileId});
      logChat.info('file data sent, waiting for ack fileId=${meta.fileId}');

      final ackCompleter = Completer<void>();
      _fileAckCompleters[meta.fileId] = ackCompleter;
      await ackCompleter.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          logChat.warning('file_ack timeout fileId=${meta.fileId}');
          throw TimeoutException(
            'file_ack timeout fileId=${meta.fileId}',
            const Duration(seconds: 120),
          );
        },
      );

      logChat.info(
        'file ack received fileId=${meta.fileId} name=${meta.fileName}',
      );
      onFileSent?.call(meta.fileId, meta.fileName);
    } catch (e, stack) {
      logChat.warning(
        'sendSingleFile failed fileId=${meta.fileId}: $e\n$stack',
      );
      if (_cancelledByRemote ||
          _locallyCancelledFiles.contains(meta.fileId)) {
        _locallyCancelledFiles.remove(meta.fileId);
        onFileCancelled?.call(meta.fileId, meta.fileName);
      } else {
        onFileFailed?.call(meta.fileId, meta.fileName, e.toString());
      }
    } finally {
      _fileAckCompleters.remove(meta.fileId);
      _fileChannelOpenCompleters.remove(meta.fileId);
    }
  }

  void _setupFileReceiveChannel(RTCDataChannel dc, String fileId) {
    int chunksSinceFlush = 0;
    const flushInterval = 128; // flush every ~2 MB (128 * 16KB)
    bool firstChunk = true;

    dc.onMessage = (msg) {
      final state = _receiveStates[fileId];
      if (state == null) return;

      if (firstChunk) {
        firstChunk = false;
        if (state.resumeRequested && !state.resumeConfirmed) {
          logChat.info(
            'WebRTC resume not confirmed, discarding partial file fileId=$fileId',
          );
          if (state.partialFilePath != null) {
            try {
              File(state.partialFilePath!).deleteSync();
            } catch (_) {}
          }
          state.received = 0;
          state.partialFilePath = null;
          state.resumeRequested = false;
          state.chunks.clear();
        }
      }

      final data = msg.binary;
      state.chunks.add(data);
      state.received += data.length;
      chunksSinceFlush++;
      onProgress?.call(fileId, state.received, state.meta.fileSize);

      // Confirm every ~256KB to stay well under sender's 4MB flow-control threshold.
      const progressInterval = 256 * 1024;
      if (state.received >= state.meta.fileSize ||
          state.received % progressInterval < data.length) {
        _sendControlMessage({
          'type': 'progress',
          'fileId': fileId,
          'received': state.received,
        });
      }

      // Periodically flush to disk to enable resume after crash.
      if (chunksSinceFlush >= flushInterval) {
        chunksSinceFlush = 0;
        _flushPartialToDisk(fileId, state);
      }

      if (state.pendingFinalize && state.received >= state.meta.fileSize) {
        _receiveStates.remove(fileId);
        _finalizeReceivedFile(fileId, state);
      }
    };
  }

  Future<void> _checkAndRequestResume(
    String fileId,
    WebRTCFileMeta meta,
  ) async {
    try {
      final dir = await _dirForIncomingFiles();
      final partialPath = '$dir/.webrtc_partial_$fileId';
      final partialFile = File(partialPath);

      // Use synchronous APIs for fast check when possible, so the
      // file_resume_request reaches the sender before it times out.
      if (partialFile.existsSync()) {
        final existingBytes = partialFile.lengthSync();
        if (existingBytes >= meta.fileSize) {
          logChat.info(
            'WebRTC resume: partial file >= fileSize, deleting stale partial fileId=$fileId',
          );
          partialFile.deleteSync();
          return;
        }
        if (existingBytes > 0) {
          logChat.info(
            'WebRTC resume: found partial file $existingBytes bytes for fileId=$fileId',
          );
          final state = _receiveStates[fileId];
          if (state != null) {
            state.received = existingBytes;
            state.partialFilePath = partialPath;
            state.resumeRequested = true;
          }
          _sendControlMessage({
            'type': 'file_resume_request',
            'fileId': fileId,
            'receivedBytes': existingBytes,
          });
        }
      }
    } catch (e) {
      logChat.warning('_checkAndRequestResume failed: $e');
    }
  }

  /// Periodically flush received chunks to a partial file on disk.
  /// Takes a snapshot of chunks and clears the list synchronously BEFORE
  /// any async work, preventing race conditions with concurrent flushes
  /// or new incoming data.
  Future<void> _flushPartialToDisk(String fileId, _ReceiveState state) async {
    if (state.chunks.isEmpty || state.flushing) return;
    state.flushing = true;
    try {
      final dir = await _dirForIncomingFiles();
      final partialPath = '$dir/.webrtc_partial_$fileId';
      state.partialFilePath = partialPath;
      final chunksToWrite = List<Uint8List>.from(state.chunks);
      state.chunks.clear();
      final sink = File(partialPath).openWrite(mode: FileMode.append);
      for (final chunk in chunksToWrite) {
        sink.add(chunk);
      }
      await sink.close();
    } catch (e) {
      logChat.warning('_flushPartialToDisk failed: $e');
    } finally {
      state.flushing = false;
    }
  }

  Future<void> _finalizeReceivedFile(String fileId, _ReceiveState state) async {
    try {
      final dir = await _dirForIncomingFiles();
      // One-file-per-directory layout: <saveDir>/<messageId>/<originalName>.
      // messageId mirrors the convention used in chat_screen.dart so the chat
      // bubble and the file index always agree on a key.
      final messageId = 'webrtc_recv_$fileId';
      final perFileDir = Directory('$dir/$messageId');
      if (!await perFileDir.exists()) {
        await perFileDir.create(recursive: true);
      }
      final filePath = _resolveUniqueWebRtcPath(
        perFileDir.path,
        state.meta.fileName,
      );

      if (state.partialFilePath != null) {
        // Append remaining chunks to the partial file, then rename.
        final partialFile = File(state.partialFilePath!);
        if (state.chunks.isNotEmpty) {
          final sink = partialFile.openWrite(mode: FileMode.append);
          for (final chunk in state.chunks) {
            sink.add(chunk);
          }
          await sink.close();
        }
        await partialFile.rename(filePath);
      } else {
        final outFile = File(filePath);
        final sink = outFile.openWrite();
        for (final chunk in state.chunks) {
          sink.add(chunk);
        }
        await sink.close();
      }

      // Clean up partial file.
      final partialCleanup = File('$dir/.webrtc_partial_$fileId');
      if (await partialCleanup.exists()) {
        await partialCleanup.delete();
      }

      await applyReceivedFileTimestamps(
        filePath,
        state.meta.lastModifiedMs,
      );

      _sendControlMessage({
        'type': 'file_ack',
        'fileId': fileId,
        'success': true,
      });
      onFileReceived?.call(fileId, state.meta.fileName, filePath);
      logChat.info('WebRTC file received: ${state.meta.fileName} -> $filePath');
    } catch (e) {
      logChat.warning('Failed to save received file: $e');
      _sendControlMessage({
        'type': 'file_ack',
        'fileId': fileId,
        'success': false,
        'error': e.toString(),
      });
    }
  }

  void close() {
    _clearConnectionTimer();
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    for (final waiter in _flowControlWaiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(Exception('Session closed'));
      }
    }
    _flowControlWaiters.clear();
    for (final waiter in _resumeWaiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(Exception('Session closed'));
      }
    }
    _resumeWaiters.clear();
    for (final ack in _fileAckCompleters.values) {
      if (!ack.isCompleted) {
        ack.completeError(Exception('Session closed'));
      }
    }
    _fileAckCompleters.clear();
    for (final dc in _fileChannels.values) {
      dc.close();
    }
    _fileChannels.clear();
    _controlChannel?.close();
    _pc?.close();
    _pc?.dispose();
    logChat.info('session closed session=$sessionId');
  }
}

class PendingSend {
  final String filePath;
  final WebRTCFileMeta meta;
  PendingSend({required this.filePath, required this.meta});
}

/// Resolve `<dir>/<originalName>`, falling back to `name (1).ext` style
/// suffixes if a file already exists. Kept local to avoid a circular import
/// from `services/file_store.dart`.
String _resolveUniqueWebRtcPath(String dir, String originalName) {
  final base = originalName.isEmpty ? 'received' : originalName;
  final candidate = '$dir/$base';
  if (!File(candidate).existsSync()) return candidate;
  final dotIdx = base.lastIndexOf('.');
  final hasExt = dotIdx > 0 && dotIdx < base.length - 1;
  final stem = hasExt ? base.substring(0, dotIdx) : base;
  final ext = hasExt ? base.substring(dotIdx) : '';
  for (int i = 1; i < 10000; i++) {
    final next = '$dir/$stem ($i)$ext';
    if (!File(next).existsSync()) return next;
  }
  return '$dir/$stem ${DateTime.now().millisecondsSinceEpoch}$ext';
}

class _ReceiveState {
  final WebRTCFileMeta meta;
  final List<Uint8List> chunks = [];
  int received = 0;
  bool pendingFinalize = false;
  String? partialFilePath;
  bool resumeRequested = false;
  bool resumeConfirmed = false;
  bool flushing = false;
  _ReceiveState({required this.meta});
}

class WebRTCManager {
  final Map<String, WebRTCSession> _sessions = {};

  OnFileProgress? onProgress;
  OnFileReceived? onFileReceived;
  OnFileSent? onFileSent;
  OnFileFailed? onFileFailed;
  OnFileCancelled? onFileCancelled;
  OnSessionStateChange? onStateChange;
  String? saveDirPath;

  WebRTCSession _createSession(
    String sessionId,
    String remoteDeviceId,
    String localDeviceId,
  ) {
    final existing = _sessions[sessionId];
    if (existing != null) {
      existing.close();
    }
    final session = WebRTCSession(
      sessionId: sessionId,
      remoteDeviceId: remoteDeviceId,
      localDeviceId: localDeviceId,
      saveDirPath: saveDirPath,
    );
    session.onProgress = (fileId, received, total) =>
        onProgress?.call(fileId, received, total);
    session.onFileReceived = (fileId, fileName, filePath) =>
        onFileReceived?.call(fileId, fileName, filePath);
    session.onFileSent = (fileId, fileName) =>
        onFileSent?.call(fileId, fileName);
    session.onFileFailed = (fileId, fileName, error) =>
        onFileFailed?.call(fileId, fileName, error);
    session.onFileCancelled = (fileId, fileName) =>
        onFileCancelled?.call(fileId, fileName);
    session.onStateChange = (sid, state) => onStateChange?.call(sid, state);
    _sessions[sessionId] = session;
    return session;
  }

  Future<WebRTCSession> initiateTransfer({
    required String targetDeviceId,
    required String localDeviceId,
    required List<({String filePath, WebRTCFileMeta meta})> files,
  }) async {
    final sessionId = const Uuid().v4();
    final session = _createSession(sessionId, targetDeviceId, localDeviceId);
    final pendingSends = files
        .map((f) => PendingSend(filePath: f.filePath, meta: f.meta))
        .toList();
    await session.createOffer(pendingSends);
    return session;
  }

  void handleSignal(Map<String, dynamic> signal, String localDeviceId) {
    final type = signal['type'] as String?;
    final sessionId = signal['sessionId'] as String?;
    final targetDeviceId = signal['targetDeviceId'] as String?;
    final senderDeviceId = signal['senderDeviceId'] as String?;

    if (type == null || sessionId == null || targetDeviceId != localDeviceId)
      return;

    switch (type) {
      case 'webrtc_offer':
        final session = _createSession(
          sessionId,
          senderDeviceId ?? '',
          localDeviceId,
        );
        session
            .handleOffer(signal)
            .catchError((e) => logChat.warning('handleOffer failed: $e'));
        break;
      case 'webrtc_answer':
        _sessions[sessionId]
            ?.handleAnswer(signal)
            .catchError((e) => logChat.warning('handleAnswer failed: $e'));
        break;
      case 'webrtc_ice_candidate':
        _sessions[sessionId]
            ?.handleIceCandidate(signal)
            .catchError(
              (e) => logChat.warning('handleIceCandidate failed: $e'),
            );
        break;
      case 'webrtc_transfer_cancel':
        final session = _sessions.remove(sessionId);
        session?.handleTransferCancel();
        break;
    }
  }

  /// Cancel a single file inside a (possibly multi-file) session. The session
  /// itself stays open so the other files keep streaming.
  void cancelTransferByFileId(String fileId) {
    WebRTCSession? matched;
    for (final session in _sessions.values) {
      final hasPending = session._pendingSends.any(
        (p) => p.meta.fileId == fileId,
      );
      final hasReceive = session._receiveStates.containsKey(fileId);
      if (hasPending || hasReceive) {
        matched = session;
        break;
      }
    }
    if (matched == null) return;
    matched.cancelFile(fileId);
  }

  /// Tear down an entire WebRTC session (every file inside it). Used when the
  /// user explicitly closes the session, not for per-file cancel.
  void cancelSession(String sessionId) {
    final session = _sessions.remove(sessionId);
    if (session == null) return;
    sendWebRTCSignal({
      'type': 'webrtc_transfer_cancel',
      'sessionId': session.sessionId,
      'senderDeviceId': session.localDeviceId,
      'targetDeviceId': session.remoteDeviceId,
    });
    session.close();
  }

  void removeSession(String sessionId) {
    final session = _sessions.remove(sessionId);
    session?.close();
  }

  void closeAll() {
    for (final session in _sessions.values) {
      session.close();
    }
    _sessions.clear();
  }
}

// ---------------------------------------------------------------------------
// Lightweight ICE candidate gathering for probe connectivity check
// ---------------------------------------------------------------------------

const _iceGatherTimeout = Duration(seconds: 3);
const _iceSummaryCacheTtl = Duration(seconds: 30);

IceCandidateSummary? _cachedIceSummary;
DateTime? _cachedIceSummaryAt;

class IceCandidateSummary {
  final bool hasSrflx;
  final bool hasRelay;
  final Set<String> publicIps;

  IceCandidateSummary({
    required this.hasSrflx,
    required this.hasRelay,
    required this.publicIps,
  });

  factory IceCandidateSummary.empty() => IceCandidateSummary(
    hasSrflx: false,
    hasRelay: false,
    publicIps: {},
  );

  Map<String, dynamic> toJson() => {
    'hasSrflx': hasSrflx,
    'hasRelay': hasRelay,
    'publicIps': publicIps.toList(),
  };

  factory IceCandidateSummary.fromJson(Map<String, dynamic> j) =>
      IceCandidateSummary(
        hasSrflx: j['hasSrflx'] == true,
        hasRelay: j['hasRelay'] == true,
        publicIps: (j['publicIps'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            {},
      );

  /// Analyze connectivity likelihood between two sides.
  /// Returns: 'online' (same network), 'connectable' (might work),
  ///          'offline' (unlikely to work).
  static String analyzeConnectivity(
    IceCandidateSummary local,
    IceCandidateSummary remote,
  ) {
    if (!local.hasSrflx || !remote.hasSrflx) return 'offline';
    final shared = local.publicIps.intersection(remote.publicIps);
    if (shared.isNotEmpty) return 'online';
    return 'connectable';
  }
}

/// Creates a temporary PeerConnection, gathers ICE candidates, and returns
/// a summary of candidate types found. Used during probe to assess whether
/// a WebRTC P2P connection is likely to succeed.
Future<IceCandidateSummary> gatherIceCandidates() async {
  final cachedAt = _cachedIceSummaryAt;
  final cached = _cachedIceSummary;
  if (cached != null &&
      cachedAt != null &&
      DateTime.now().difference(cachedAt) < _iceSummaryCacheTtl) {
    return cached;
  }

  final config = <String, dynamic>{
    'iceServers': <Map<String, dynamic>>[
      {'urls': 'stun:stun.miwifi.com:3478'},
      {'urls': 'stun:stun.qq.com:3478'},
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  RTCPeerConnection? pc;
  try {
    pc = await createPeerConnection(config);

    final dcInit = RTCDataChannelInit()..ordered = true;
    await pc.createDataChannel('_ice_probe', dcInit);

    bool hasSrflx = false;
    bool hasRelay = false;
    final publicIps = <String>{};
    final gatherDone = Completer<void>();

    pc.onIceCandidate = (candidate) {
      final c = candidate.candidate;
      if (c == null || c.isEmpty) return;
      if (c.contains(' typ srflx ')) {
        hasSrflx = true;
        final ip = _extractIpFromCandidate(c);
        if (ip != null) publicIps.add(ip);
      } else if (c.contains(' typ relay ')) {
        hasRelay = true;
      }
    };

    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!gatherDone.isCompleted) gatherDone.complete();
      }
    };

    final offer = await pc.createOffer({});
    await pc.setLocalDescription(offer);

    await gatherDone.future.timeout(_iceGatherTimeout, onTimeout: () {});

    logChat.info(
      'ICE probe: hasSrflx=$hasSrflx hasRelay=$hasRelay '
      'publicIps=$publicIps',
    );

    final summary = IceCandidateSummary(
      hasSrflx: hasSrflx,
      hasRelay: hasRelay,
      publicIps: publicIps,
    );
    _cachedIceSummary = summary;
    _cachedIceSummaryAt = DateTime.now();
    return summary;
  } catch (e) {
    logChat.warning('gatherIceCandidates failed: $e');
    return IceCandidateSummary.empty();
  } finally {
    pc?.close();
    pc?.dispose();
  }
}

String? _extractIpFromCandidate(String candidate) {
  // SDP format: "candidate:foundation component transport priority addr port typ type ..."
  final parts = candidate.split(' ');
  if (parts.length >= 5) return parts[4];
  return null;
}
