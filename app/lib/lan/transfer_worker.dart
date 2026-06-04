import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../services/cancel_token.dart';
import '../services/mtime_util.dart';
import '../services/transfer_protocol.dart';
import '../utils/safe_filename.dart';
import 'lan_url.dart';

final _log = Logger('ultrasend.transfer_worker');

typedef OnLanFileReceived =
    void Function(
      String filePath,
      String fileName,
      String? fromDeviceId, {
      String? messageId,
      String? senderLocalId,
      int? lastModifiedMs,
    });
typedef OnLanReceiveProgress =
    void Function(
      String fileName,
      int received,
      int total, {
      String? messageId,
      String? senderLocalId,
      String? fileId,
    });
typedef OnLanReceiveError = void Function(
  String fileName,
  String error, {
  String? messageId,
  String? senderLocalId,
  String? fileId,
});
typedef OnPullSendProgress = void Function(int sent, int total);
typedef OnLanMessageReceived = void Function(
  String text,
  String fromDeviceId,
  String? fromDeviceName,
);

// ---------------------------------------------------------------------------
// Worker ↔ Main Isolate messages
// ---------------------------------------------------------------------------

sealed class _ToMain {}

class _FileReceived extends _ToMain {
  _FileReceived(
    this.filePath,
    this.fileName, {
    this.fromDeviceId,
    this.messageId,
    this.senderLocalId,
    this.lastModifiedMs,
  });
  final String filePath;
  final String fileName;
  final String? fromDeviceId;
  final String? messageId;
  final String? senderLocalId;
  final int? lastModifiedMs;
}

class _ReceiveProgress extends _ToMain {
  _ReceiveProgress(
    this.fileName,
    this.received,
    this.total, {
    this.messageId,
    this.senderLocalId,
    this.fileId,
  });
  final String fileName;
  final int received;
  final int total;
  final String? messageId;
  final String? senderLocalId;
  final String? fileId;
}

class _WorkerReady extends _ToMain {
  _WorkerReady(this.commandPort);
  final SendPort commandPort;
}

sealed class _ToWorker {}

class _RegisterPull extends _ToWorker {
  _RegisterPull({
    required this.offerId,
    required this.fileName,
    required this.size,
    this.filePath,
    this.bytes,
    this.lastModifiedMs,
  });
  final String offerId;
  final String fileName;
  final int size;
  final String? filePath;
  final Uint8List? bytes;
  final int? lastModifiedMs;
}

class _CancelPull extends _ToWorker {
  _CancelPull(this.offerId);
  final String offerId;
}

class _CancelReceive extends _ToWorker {
  _CancelReceive(this.fileName, {this.fileId});
  final String fileName;

  /// Stable per-transfer identifier from the sender's
  /// `X-File-Id` header. Preferred over [fileName] because multiple concurrent
  /// transfers can share the same fileName (different senders, retries,
  /// duplicates) and `fileName`-keyed cancellation would tear them all down.
  final String? fileId;
}

class _PullProgressReport extends _ToMain {
  _PullProgressReport(this.offerId, this.sent, this.total);
  final String offerId;
  final int sent;
  final int total;
}

class _PullCompleted extends _ToMain {
  _PullCompleted(this.offerId, this.success);
  final String offerId;
  final bool success;
}

class _ReceiveError extends _ToMain {
  _ReceiveError(
    this.fileName,
    this.error, {
    this.messageId,
    this.senderLocalId,
    this.fileId,
  });
  final String fileName;
  final String error;
  final String? messageId;
  final String? senderLocalId;
  final String? fileId;
}

class _MessageReceived extends _ToMain {
  _MessageReceived({
    required this.text,
    required this.fromDeviceId,
    this.fromDeviceName,
  });
  final String text;
  final String fromDeviceId;
  final String? fromDeviceName;
}

class _PeerRegistered extends _ToMain {
  _PeerRegistered({
    required this.deviceId,
    required this.name,
    required this.lanHttpUrl,
    this.platform,
  });
  final String deviceId;
  final String name;
  final String lanHttpUrl;
  final String? platform;
}

/// Cross-worker fan-out: a peer hit `/cancel` on worker A but the actual
/// upload may live on worker B. Worker A relays this hint to the main
/// isolate which re-broadcasts it to every worker via the existing
/// `_CancelReceive` command channel.
class _CancelHintFromPeer extends _ToMain {
  _CancelHintFromPeer({this.fileId, this.fileName});
  final String? fileId;
  final String? fileName;
}

// ---------------------------------------------------------------------------
// Pending pull file (lives inside worker isolate)
// ---------------------------------------------------------------------------

class _WorkerPullFile {
  _WorkerPullFile({
    required this.fileName,
    required this.size,
    this.filePath,
    this.bytes,
    this.lastModifiedMs,
  });
  final String fileName;
  final int size;
  final String? filePath;
  final Uint8List? bytes;
  final int? lastModifiedMs;
}

// ---------------------------------------------------------------------------
// HttpTransferServer — runs N worker Isolates sharing one port
// ---------------------------------------------------------------------------

typedef OnPeerRegistered = void Function(
  String deviceId,
  String name,
  String lanHttpUrl,
  String? platform,
);

class HttpTransferServer {
  HttpTransferServer({
    required this.onFileReceived,
    this.onReceiveProgress,
    this.onReceiveError,
    this.onMessageReceived,
    this.onPeerRegistered,
  });

  final OnLanFileReceived onFileReceived;
  final OnLanReceiveProgress? onReceiveProgress;
  final OnLanReceiveError? onReceiveError;
  final OnLanMessageReceived? onMessageReceived;
  final OnPeerRegistered? onPeerRegistered;

  String? _lanHttpUrl;
  String? get lanHttpUrl => _lanHttpUrl;

  final List<Isolate> _workers = [];
  final List<SendPort> _workerPorts = [];
  final List<ReceivePort> _mainPorts = [];

  final Map<String, _PullCallbacks> _pullCallbacks = {};

  Future<String?> start(
    String bindAddress,
    int port,
    int workerCount,
    String saveDir, {
    String? deviceId,
    String? deviceName,
    String? platform,
  }) async {
    for (int i = 0; i < workerCount; i++) {
      final mainPort = ReceivePort();
      _mainPorts.add(mainPort);

      final isolate = await Isolate.spawn(_workerEntry, [
        mainPort.sendPort,
        bindAddress,
        port,
        saveDir,
        deviceId ?? '',
        deviceName ?? '',
        platform ?? '',
      ], debugName: 'http-worker-$i');
      _workers.add(isolate);

      final readyCompleter = Completer<SendPort>();
      mainPort.listen((msg) {
        if (msg is _WorkerReady) {
          readyCompleter.complete(msg.commandPort);
        } else if (msg is _ToMain) {
          _handleWorkerMessage(msg);
        }
      });

      final cmdPort = await readyCompleter.future;
      _workerPorts.add(cmdPort);
    }

    _lanHttpUrl = buildLanHttpBaseUrl(bindAddress, port);
    _log.info(
      'HttpTransferServer started at $_lanHttpUrl ($workerCount workers)',
    );
    return _lanHttpUrl;
  }

  void registerPullFile(
    String offerId,
    String fileName,
    int size, {
    String? filePath,
    Uint8List? bytes,
    int? lastModifiedMs,
    VoidCallback? onPullStarted,
    OnPullSendProgress? onSendProgress,
    VoidCallback? onPullCompleted,
    Completer<bool>? completer,
  }) {
    _pullCallbacks[offerId] = _PullCallbacks(
      onPullStarted: onPullStarted,
      onSendProgress: onSendProgress,
      onPullCompleted: onPullCompleted,
      completer: completer,
    );
    final msg = _RegisterPull(
      offerId: offerId,
      fileName: fileName,
      size: size,
      filePath: filePath,
      bytes: bytes,
      lastModifiedMs: lastModifiedMs ?? readMtimeMs(filePath),
    );
    for (final port in _workerPorts) {
      port.send(msg);
    }
  }

  void unregisterPullFile(String offerId) {
    _pullCallbacks.remove(offerId);
    for (final port in _workerPorts) {
      port.send(_CancelPull(offerId));
    }
  }

  /// Signal worker isolates to cancel an ongoing receive.
  ///
  /// Prefer passing [fileId] (derived from the `X-File-Id` header) so that
  /// only the targeted transfer is interrupted; falling back to [fileName]
  /// matches any active receive with that name (legacy behaviour).
  void cancelReceive(String fileName, {String? fileId}) {
    final msg = _CancelReceive(fileName, fileId: fileId);
    for (final port in _workerPorts) {
      port.send(msg);
    }
  }

  Future<void> stop() async {
    for (final isolate in _workers) {
      isolate.kill(priority: Isolate.immediate);
    }
    for (final port in _mainPorts) {
      port.close();
    }
    _workers.clear();
    _workerPorts.clear();
    _mainPorts.clear();
    _lanHttpUrl = null;
    _log.info('HttpTransferServer stopped');
  }

  void _handleWorkerMessage(_ToMain msg) {
    switch (msg) {
      case _FileReceived():
        onFileReceived(
          msg.filePath,
          msg.fileName,
          msg.fromDeviceId,
          messageId: msg.messageId,
          senderLocalId: msg.senderLocalId,
          lastModifiedMs: msg.lastModifiedMs,
        );

      case _ReceiveProgress():
        onReceiveProgress?.call(
          msg.fileName,
          msg.received,
          msg.total,
          messageId: msg.messageId,
          senderLocalId: msg.senderLocalId,
          fileId: msg.fileId,
        );

      case _PullProgressReport():
        final cb = _pullCallbacks[msg.offerId];
        if (cb != null) {
          cb.pullStarted();
          cb.onSendProgress?.call(msg.sent, msg.total);
        }

      case _PullCompleted():
        final cb = _pullCallbacks[msg.offerId];
        if (cb != null) {
          cb.pullStarted();
          if (msg.success) {
            cb.onSendProgress?.call(0, 0);
            cb.onPullCompleted?.call();
          }
          cb.completer?.complete(msg.success);
          _pullCallbacks.remove(msg.offerId);
        }

      case _ReceiveError():
        onReceiveError?.call(
          msg.fileName,
          msg.error,
          messageId: msg.messageId,
          senderLocalId: msg.senderLocalId,
          fileId: msg.fileId,
        );

      case _MessageReceived():
        onMessageReceived?.call(
          msg.text,
          msg.fromDeviceId,
          msg.fromDeviceName,
        );

      case _PeerRegistered():
        onPeerRegistered?.call(
          msg.deviceId,
          msg.name,
          msg.lanHttpUrl,
          msg.platform,
        );

      case _CancelHintFromPeer():
        // Re-broadcast across every worker so whichever isolate currently
        // holds the upload stream learns about the cancel without waiting
        // for the read timeout.
        final relay = _CancelReceive(
          msg.fileName ?? '',
          fileId: msg.fileId,
        );
        for (final port in _workerPorts) {
          port.send(relay);
        }

      case _WorkerReady():
        break;
    }
  }
}

class _PullCallbacks {
  _PullCallbacks({
    this.onPullStarted,
    this.onSendProgress,
    this.onPullCompleted,
    this.completer,
  });
  final VoidCallback? onPullStarted;
  final OnPullSendProgress? onSendProgress;
  final VoidCallback? onPullCompleted;
  final Completer<bool>? completer;
  bool _started = false;
  void pullStarted() {
    if (!_started) {
      _started = true;
      onPullStarted?.call();
    }
  }
}

typedef VoidCallback = void Function();

// ---------------------------------------------------------------------------
// Worker Isolate entry point
// ---------------------------------------------------------------------------

void _workerEntry(List<dynamic> args) async {
  final mainPort = args[0] as SendPort;
  final address = args[1] as String;
  final port = args[2] as int;
  final saveDir = args[3] as String;
  final deviceId = args.length > 4 ? args[4] as String : '';
  final deviceName = args.length > 5 ? args[5] as String : '';
  final platform = args.length > 6 ? args[6] as String : '';

  final pullFiles = <String, _WorkerPullFile>{};
  // Tracks partially received files by fileId → (filePath, receivedBytes).
  final partialReceives = <String, _PartialReceive>{};
  // Per-fileId generation counter to prevent concurrent uploads for the same file.
  final uploadGeneration = <String, int>{};
  // File ids whose receive has been cancelled by the user (preferred path).
  final cancelledReceivesById = <String>{};
  // Legacy: file names cancelled when the sender did not provide a fileId.
  final cancelledReceivesByName = <String>{};
  // Pull offers cancelled by the sender while a receiver may already be
  // streaming `/download?offerId=...`.
  final cancelledPullOffers = <String>{};

  late HttpServer server;
  try {
    server = await HttpServer.bind(address, port, shared: true);
  } catch (_) {
    return;
  }

  final commandPort = ReceivePort();
  mainPort.send(_WorkerReady(commandPort.sendPort));

  commandPort.listen((msg) {
    if (msg is _RegisterPull) {
      cancelledPullOffers.remove(msg.offerId);
      pullFiles[msg.offerId] = _WorkerPullFile(
        fileName: msg.fileName,
        size: msg.size,
        filePath: msg.filePath,
        bytes: msg.bytes,
        lastModifiedMs: msg.lastModifiedMs,
      );
    } else if (msg is _CancelPull) {
      cancelledPullOffers.add(msg.offerId);
      pullFiles.remove(msg.offerId);
    } else if (msg is _CancelReceive) {
      if (msg.fileId != null && msg.fileId!.isNotEmpty) {
        cancelledReceivesById.add(msg.fileId!);
      } else {
        cancelledReceivesByName.add(msg.fileName);
      }
    }
  });

  await for (final request in server) {
    _setCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.noContent
        ..close();
      continue;
    }

    switch (request.uri.path) {
      case '/transfer':
        if (request.method == 'POST') {
          _handleUpload(
            request,
            saveDir,
            mainPort,
            partialReceives,
            deviceId,
            uploadGeneration: uploadGeneration,
            cancelledReceivesById: cancelledReceivesById,
            cancelledReceivesByName: cancelledReceivesByName,
          );
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..close();
        }
      case '/transfer-status':
        if (request.method == 'GET' || request.method == 'HEAD') {
          _handleTransferStatus(request, partialReceives, saveDir);
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..close();
        }
      case '/cancel':
        if (request.method == 'POST' || request.method == 'GET') {
          _handleCancelUpload(
            request,
            mainPort,
            cancelledReceivesById,
            cancelledReceivesByName,
          );
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..close();
        }
      case '/download':
        if (request.method == 'GET') {
          _handleDownload(request, pullFiles, mainPort, cancelledPullOffers);
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..close();
        }
      case '/probe':
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('ok')
          ..close();
      case '/device-info':
        if (request.method == 'GET') {
          _handleDeviceInfo(request, deviceId, deviceName, platform);
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..close();
        }
      case '/message':
        if (request.method == 'POST') {
          _handleMessagePost(request, mainPort, deviceId);
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..close();
        }
      case '/register-peer':
        if (request.method == 'POST') {
          _handleRegisterPeer(request, mainPort);
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..close();
        }
      default:
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
    }
  }
}

class _PartialReceive {
  _PartialReceive({required this.filePath, required this.receivedBytes});
  final String filePath;
  int receivedBytes;
}

/// Application-level cancel signal from the sender. Without this the receiver
/// would only learn about a cancel once the TCP connection actually drops,
/// which can take up to the iterator read timeout — long enough to look like a
/// hang in the UI.
///
/// Because the upload might be handled by a different worker isolate than the
/// one serving this `/cancel` request (the port is shared via `reusePort`), we
/// also relay the hint through [mainPort] so [HttpTransferServer] can fan it
/// out to every worker.
void _handleCancelUpload(
  HttpRequest request,
  SendPort mainPort,
  Set<String> cancelledReceivesById,
  Set<String> cancelledReceivesByName,
) {
  final fileId = request.uri.queryParameters['fileId'];
  final rawFileName = request.uri.queryParameters['fileName'];
  final fileName = rawFileName != null && rawFileName.isNotEmpty
      ? Uri.decodeComponent(rawFileName)
      : null;
  if ((fileId == null || fileId.isEmpty) &&
      (fileName == null || fileName.isEmpty)) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('missing fileId or fileName')
      ..close();
    return;
  }
  if (fileId != null && fileId.isNotEmpty) {
    cancelledReceivesById.add(fileId);
  }
  if (fileName != null && fileName.isNotEmpty) {
    cancelledReceivesByName.add(fileName);
  }
  mainPort.send(_CancelHintFromPeer(fileId: fileId, fileName: fileName));
  _log.info(
    'cancel signal received fileId=$fileId fileName=$fileName',
  );
  request.response
    ..statusCode = HttpStatus.ok
    ..close();
}

void _handleTransferStatus(
  HttpRequest request,
  Map<String, _PartialReceive> partialReceives,
  String saveDir,
) {
  final fileId = request.uri.queryParameters['fileId'];
  if (fileId == null || fileId.isEmpty) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('missing fileId')
      ..close();
    return;
  }

  // Always use the actual file size on disk as the source of truth.
  // Multiple worker isolates share the same disk files but have independent
  // in-memory maps, so a stale in-memory entry would return a wrong offset.
  int received = 0;
  final partialFile = File('$saveDir/.lan_partial_$fileId');
  if (partialFile.existsSync()) {
    received = partialFile.lengthSync();
  }
  final partial = partialReceives[fileId];
  if (partial != null) {
    partial.receivedBytes = received;
  } else if (received > 0) {
    partialReceives[fileId] = _PartialReceive(
      filePath: partialFile.path,
      receivedBytes: received,
    );
  }

  request.response
    ..statusCode = HttpStatus.ok
    ..headers.set(TransferProtocol.headerReceivedBytes, received.toString())
    ..write(received.toString())
    ..close();
}

void _handleDeviceInfo(
  HttpRequest request,
  String deviceId,
  String deviceName,
  String platform,
) {
  final body = '{"deviceId":"${_escapeJson(deviceId)}","name":"${_escapeJson(deviceName)}","platform":"${_escapeJson(platform)}"}';
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType('application', 'json')
    ..write(body)
    ..close();
}

String _escapeJson(String s) {
  return s
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
}

Future<void> _handleMessagePost(
  HttpRequest request,
  SendPort mainPort,
  String myDeviceId,
) async {
  try {
    final bodyBytes = await request.fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    final body = utf8.decode(bodyBytes);
    final map = jsonDecode(body) as Map<String, dynamic>?;
    final text = map?['text']?.toString() ?? '';
    final fromDeviceId = map?['fromDeviceId']?.toString() ?? '';
    final fromDeviceName = map?['fromDeviceName']?.toString();
    if (text.isEmpty || fromDeviceId.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    // 防止局域网内 URL / mDNS 映射错误时「串号」：仅当 body 声明了收件方且与本机不符时丢弃。
    final toDeviceId = map?['toDeviceId']?.toString();
    if (toDeviceId != null &&
        toDeviceId.isNotEmpty &&
        myDeviceId.isNotEmpty &&
        toDeviceId != myDeviceId) {
      _log.fine(
        'Message POST rejected: toDeviceId=$toDeviceId expected self=$myDeviceId '
        'from=$fromDeviceId',
      );
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
      return;
    }
    mainPort.send(_MessageReceived(
      text: text,
      fromDeviceId: fromDeviceId,
      fromDeviceName: fromDeviceName,
    ));
    request.response
      ..statusCode = HttpStatus.ok
      ..close();
  } catch (e) {
    _log.warning('Message POST error: $e');
    request.response
      ..statusCode = HttpStatus.badRequest
      ..close();
  }
}

Future<void> _handleRegisterPeer(HttpRequest request, SendPort mainPort) async {
  try {
    final bodyBytes = await request.fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    final body = utf8.decode(bodyBytes);
    final map = jsonDecode(body) as Map<String, dynamic>?;
    final peerDeviceId = map?['deviceId']?.toString() ?? '';
    final peerName = map?['name']?.toString() ?? '';
    final peerLanHttpUrl = map?['lanHttpUrl']?.toString() ?? '';
    final peerPlatform = map?['platform']?.toString();
    if (peerDeviceId.isEmpty || peerLanHttpUrl.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }
    mainPort.send(_PeerRegistered(
      deviceId: peerDeviceId,
      name: peerName.isNotEmpty ? peerName : peerDeviceId,
      lanHttpUrl: peerLanHttpUrl,
      platform: peerPlatform,
    ));
    request.response
      ..statusCode = HttpStatus.ok
      ..close();
  } catch (e) {
    _log.warning('RegisterPeer POST error: $e');
    request.response
      ..statusCode = HttpStatus.badRequest
      ..close();
  }
}

void _setCorsHeaders(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET, POST, HEAD, OPTIONS')
    ..set(
      'Access-Control-Allow-Headers',
      'Content-Type, X-File-Name, X-File-Size, X-File-Id, X-Resume-Offset, Range, ${TransferProtocol.headerFromDeviceId}, ${TransferProtocol.headerToDeviceId}, ${TransferProtocol.headerFileMtimeMs}, ${TransferProtocol.headerLocalId}',
    )
    ..set(
      'Access-Control-Expose-Headers',
      'X-File-Name, X-File-Size, X-Received-Bytes, Content-Range, ${TransferProtocol.headerFileMtimeMs}',
    );
}

Future<void> _handleUpload(
  HttpRequest request,
  String saveDir,
  SendPort mainPort,
  Map<String, _PartialReceive> partialReceives,
  String myDeviceId, {
  Map<String, int>? uploadGeneration,
  Set<String>? cancelledReceivesById,
  Set<String>? cancelledReceivesByName,
}) async {
  final headers = request.headers;
  final rawIntendedTo = headers.value(TransferProtocol.headerToDeviceId);
  final intendedTo = rawIntendedTo != null ? rawIntendedTo.trim() : '';
  if (intendedTo.isNotEmpty &&
      myDeviceId.isNotEmpty &&
      intendedTo != myDeviceId) {
    _log.fine(
      'Upload rejected: ${TransferProtocol.headerToDeviceId}=$intendedTo '
      'self=$myDeviceId',
    );
    request.response
      ..statusCode = HttpStatus.forbidden
      ..close();
    return;
  }
  final fileName = Uri.decodeComponent(
    headers.value('X-File-Name') ?? 'received',
  );
  final diskName = sanitizeFileNameForLocalStorage(fileName);
  // Sender-supplied per-transfer localId (UUID) when available. We use it as
  // the receiver-side messageId so the chat bubble, the Centrifugo file
  // publication and the received_files row share the same key. When absent
  // (older peers) we mint a UUID locally so every transfer still gets a
  // unique id — never derive from fileName.
  final rawSenderLocalId = headers.value(TransferProtocol.headerLocalId);
  final senderLocalId =
      (rawSenderLocalId != null && rawSenderLocalId.trim().isNotEmpty)
      ? rawSenderLocalId.trim()
      : null;
  final messageId = senderLocalId != null
      ? 'lan_recv_$senderLocalId'
      : 'lan_recv_${const Uuid().v4()}';
  try {
    final fileSize = int.tryParse(headers.value('X-File-Size') ?? '') ?? 0;
    final fileId = headers.value(TransferProtocol.headerFileId);
    final resumeOffset =
        int.tryParse(
          headers.value(TransferProtocol.headerResumeOffset) ?? '',
        ) ??
        0;
    final senderMtimeMs = parseMtimeMs(
      headers.value(TransferProtocol.headerFileMtimeMs),
    );
    final rawFrom = headers.value(TransferProtocol.headerFromDeviceId);
    final fromDeviceId = (rawFrom != null && rawFrom.trim().isNotEmpty)
        ? rawFrom.trim()
        : null;

    // Bump generation counter so any previous concurrent upload for the same
    // fileId will detect the mismatch and abort.
    int myGeneration = 0;
    if (fileId != null && uploadGeneration != null) {
      myGeneration = (uploadGeneration[fileId] ?? 0) + 1;
      uploadGeneration[fileId] = myGeneration;
    }

    // Clear any previous cancellation flag for this file so a resumed
    // transfer is not killed by a stale flag.
    if (fileId != null) cancelledReceivesById?.remove(fileId);
    cancelledReceivesByName?.remove(fileName);

    String partialPath;
    FileMode writeMode;

    if (fileId != null) {
      partialPath = '$saveDir/.lan_partial_$fileId';
    } else {
      partialPath = '$saveDir/.lan_partial_${_timestampSync()}_$diskName';
    }

    final partial = fileId != null ? partialReceives[fileId] : null;
    if (partial != null && resumeOffset > 0) {
      partialPath = partial.filePath;
      writeMode = FileMode.append;
    } else if (fileId != null && resumeOffset > 0) {
      final existingPartial = File(partialPath);
      if (existingPartial.existsSync()) {
        writeMode = FileMode.append;
      } else {
        writeMode = FileMode.write;
      }
    } else {
      writeMode = FileMode.write;
    }

    // When appending, verify the sender's resumeOffset matches the actual file
    // size. Multiple worker isolates may have returned a stale offset, causing
    // the sender to start from the wrong position.
    int received = resumeOffset;
    if (writeMode == FileMode.append) {
      final partialFile = File(partialPath);
      if (partialFile.existsSync()) {
        final actualSize = partialFile.lengthSync();
        if (resumeOffset < actualSize) {
          // Sender will re-send data we already have — truncate to match.
          final raf = partialFile.openSync(mode: FileMode.writeOnlyAppend);
          raf.truncateSync(resumeOffset);
          raf.closeSync();
        } else if (resumeOffset > actualSize) {
          // Gap in data — cannot safely resume, start fresh.
          writeMode = FileMode.write;
          received = 0;
        }
      }
    }

    final sink = File(partialPath).openWrite(mode: writeMode);
    int lastReportedPct = fileSize > 0 ? (received * 100 ~/ fileSize) : 0;

    if (fileId != null) {
      partialReceives[fileId] = _PartialReceive(
        filePath: partialPath,
        receivedBytes: received,
      );
    }

    bool superseded = false;
    bool cancelled = false;
    final iterator = StreamIterator(request);
    try {
      while (true) {
        // Abort if a newer upload for the same fileId has started.
        if (fileId != null &&
            uploadGeneration != null &&
            uploadGeneration[fileId] != myGeneration) {
          superseded = true;
          break;
        }
        // Abort if the user cancelled this receive.
        final isCancelled =
            (fileId != null &&
                cancelledReceivesById?.contains(fileId) == true) ||
            cancelledReceivesByName?.contains(fileName) == true;
        if (isCancelled) {
          cancelled = true;
          break;
        }

        // Read timeout for a single chunk on a healthy LAN is sub-second; the
        // budget here is generous enough to weather a brief WiFi glitch yet
        // tight enough that a force-killed sender (no TCP FIN/RST delivered)
        // no longer pins the receiver UI in "receiving" state for ~30s.
        final hasNext = await iterator.moveNext().timeout(
          const Duration(seconds: 8),
          onTimeout: () => false,
        );
        if (!hasNext) break;
        final chunk = iterator.current;
        sink.add(chunk);
        received += chunk.length;

        if (fileId != null) {
          final p = partialReceives[fileId];
          if (p != null) p.receivedBytes = received;
        }

        if (fileSize > 0) {
          final pct = (received * 100 / fileSize).round().clamp(0, 100);
          if (pct - lastReportedPct >=
                  TransferProtocol.progressReportThreshold ||
              pct >= 100) {
            lastReportedPct = pct;
            mainPort.send(_ReceiveProgress(
              fileName,
              received,
              fileSize,
              messageId: messageId,
              senderLocalId: senderLocalId,
              fileId: fileId,
            ));
          }
        }
      }
    } finally {
      await iterator.cancel();
    }

    await sink.close();

    if (superseded) {
      _log.info('Upload superseded by newer request for fileId=$fileId');
      request.response
        ..statusCode = HttpStatus.ok
        ..close();
      return;
    }

    if (cancelled) {
      // Keep the cancellation flag intact: while a new upload restarts it'll
      // be cleared at the top of `_handleUpload`. Removing it here would race
      // with any in-flight request still draining bytes.
      // Partial file on disk is *intentionally* preserved so a later resume
      // (sender retry or cold start) can pick up from `received`.
      mainPort.send(_ReceiveError(
        fileName,
        'cancelled',
        messageId: messageId,
        senderLocalId: senderLocalId,
        fileId: fileId,
      ));
      request.response
        ..statusCode = HttpStatus.ok
        ..close();
      return;
    }

    if (fileSize > 0 && received < fileSize) {
      throw Exception(
        'sender disconnected: received $received/$fileSize bytes',
      );
    }

    // Transfer complete — rename partial file to final name.
    if (fileId != null) {
      partialReceives.remove(fileId);
      uploadGeneration?.remove(fileId);
    }

    // One-file-per-directory layout: <saveDir>/<messageId>/<originalName>.
    // messageId was derived from the sender's localId header (or a fresh UUID
    // for older peers) at the top of this handler so the chat bubble, the
    // received_files row and the Centrifugo file publication all share the
    // same key.
    final perFileDir = '$saveDir/$messageId';
    Directory(perFileDir).createSync(recursive: true);
    final finalPath = _resolveUniquePathSync(perFileDir, fileName);
    try {
      File(partialPath).renameSync(finalPath);
    } catch (_) {
      File(partialPath).copySync(finalPath);
      try {
        File(partialPath).deleteSync();
      } catch (_) {}
    }

    final finalFile = File(finalPath);
    if (fileSize > 0) {
      final onDisk = finalFile.lengthSync();
      if (onDisk != fileSize) {
        try {
          if (finalFile.existsSync()) finalFile.deleteSync();
        } catch (_) {}
        throw Exception(
          'incomplete file after finalize: expected $fileSize bytes, got $onDisk',
        );
      }
    }

    mainPort.send(_FileReceived(
      finalPath,
      fileName,
      fromDeviceId: fromDeviceId,
      messageId: messageId,
      senderLocalId: senderLocalId,
      lastModifiedMs: senderMtimeMs,
    ));
    request.response
      ..statusCode = HttpStatus.ok
      ..close();
  } catch (e) {
    _log.warning('Upload error: $e');
    mainPort.send(_ReceiveError(
      fileName,
      e.toString(),
      messageId: messageId,
      senderLocalId: senderLocalId,
      fileId: headers.value(TransferProtocol.headerFileId),
    ));
    try {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write(e.toString())
        ..close();
    } catch (_) {}
  }
}

Future<void> _handleDownload(
  HttpRequest request,
  Map<String, _WorkerPullFile> pullFiles,
  SendPort mainPort,
  Set<String> cancelledPullOffers,
) async {
  final offerId = request.uri.queryParameters['offerId'];
  try {
    if (offerId == null || offerId.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('missing offerId')
        ..close();
      return;
    }

    if (cancelledPullOffers.contains(offerId)) {
      request.response
        ..statusCode = HttpStatus.gone
        ..write('offerId cancelled')
        ..close();
      return;
    }

    final pending = pullFiles[offerId];
    if (pending == null) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('offerId not found')
        ..close();
      return;
    }

    final total = pending.size;
    void throwIfCancelled() {
      if (cancelledPullOffers.contains(offerId)) {
        throw Exception('pull cancelled');
      }
    }

    // Parse Range header for resume support.
    int rangeStart = 0;
    final rangeHeader = request.headers.value('range');
    if (rangeHeader != null) {
      final match = RegExp(r'bytes=(\d+)-').firstMatch(rangeHeader);
      if (match != null) {
        rangeStart = int.parse(match.group(1)!);
      }
    }

    final resp = request.response;
    resp.headers
      ..set('X-File-Name', Uri.encodeComponent(pending.fileName))
      ..set('X-File-Size', total.toString())
      ..set('Accept-Ranges', 'bytes')
      ..contentType = ContentType.binary;
    final pullMtimeMs = pending.lastModifiedMs ?? readMtimeMs(pending.filePath);
    if (pullMtimeMs != null) {
      resp.headers.set(
        TransferProtocol.headerFileMtimeMs,
        pullMtimeMs.toString(),
      );
    }

    final contentLength = total - rangeStart;
    if (rangeStart > 0) {
      resp.statusCode = HttpStatus.partialContent;
      resp.headers.set(
        'Content-Range',
        'bytes $rangeStart-${total - 1}/$total',
      );
    }
    resp.contentLength = contentLength;

    int sent = 0;
    if (pending.filePath != null) {
      final fileStream = File(pending.filePath!).openRead(rangeStart);
      final progressStream = fileStream.map((chunk) {
        throwIfCancelled();
        sent += chunk.length;
        mainPort.send(_PullProgressReport(offerId, rangeStart + sent, total));
        return chunk;
      });
      await resp.addStream(progressStream);
    } else if (pending.bytes != null) {
      final bytes = pending.bytes!;
      for (
        int i = rangeStart;
        i < bytes.length;
        i += TransferProtocol.readBlockSize
      ) {
        throwIfCancelled();
        final end = math.min(i + TransferProtocol.readBlockSize, bytes.length);
        resp.add(Uint8List.sublistView(bytes, i, end));
        await resp.flush();
        sent += end - i;
        mainPort.send(_PullProgressReport(offerId, rangeStart + sent, total));
      }
    }

    throwIfCancelled();
    await resp.close();
    pullFiles.remove(offerId);
    cancelledPullOffers.remove(offerId);
    mainPort.send(_PullCompleted(offerId, true));
  } catch (e) {
    if (offerId != null) {
      pullFiles.remove(offerId);
      cancelledPullOffers.remove(offerId);
      mainPort.send(_PullCompleted(offerId, false));
    }
    try {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write(e.toString())
        ..close();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Sender helpers
// ---------------------------------------------------------------------------

/// Fire-and-forget cancel hint sent to the receiver alongside (or instead of)
/// dropping the TCP connection. The receiver's `/cancel` handler flips the
/// per-file cancellation flag so the in-flight `_handleUpload` exits on its
/// next iteration without waiting for the read timeout.
Future<void> notifyCancelUpload(
  String url, {
  String? fileId,
  String? fileName,
}) async {
  if ((fileId == null || fileId.isEmpty) &&
      (fileName == null || fileName.isEmpty)) {
    return;
  }
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 3);
  client.findProxy = (uri) => 'DIRECT';
  try {
    final query = <String, String>{
      if (fileId != null && fileId.isNotEmpty) 'fileId': fileId,
      if (fileName != null && fileName.isNotEmpty)
        'fileName': Uri.encodeComponent(fileName),
    };
    final qs = query.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    final uri = Uri.parse('$url/cancel?$qs');
    final request = await client.postUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
  } catch (e) {
    _log.fine('notifyCancelUpload($url) ignored: $e');
  } finally {
    client.close();
  }
}

/// Query the receiver's transfer status for a given fileId.
/// Returns the number of bytes already received, or 0 if unknown.
Future<int> queryTransferStatus(String url, String fileId) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 5);
  client.findProxy = (uri) => 'DIRECT';
  try {
    final uri = Uri.parse(
      '$url/transfer-status?fileId=${Uri.encodeComponent(fileId)}',
    );
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode == HttpStatus.ok) {
      final body = await response
          .transform(const SystemEncoding().decoder)
          .join()
          .timeout(const Duration(seconds: 5));
      return int.tryParse(body.trim()) ?? 0;
    }
    await response.drain<void>();
    return 0;
  } catch (_) {
    return 0;
  } finally {
    client.close();
  }
}

/// Generate a stable file identifier for resume matching.
///
/// When [localId] is present (per-transfer UUID from the sender), it is
/// included so concurrent batch uploads with the same name/size do not share
/// `.lan_partial_<fileId>` across workers. Older peers without [localId] keep
/// the legacy `name|size` key for resume compatibility.
///
/// Must be stable across isolates / cold starts. Dart's `String.hashCode` is
/// not stable across VM runs, so we use a truncated SHA-1 instead.
String makeFileId(
  String fileName,
  int fileSize, {
  String? localId,
}) {
  final key = (localId != null && localId.trim().isNotEmpty)
      ? '${localId.trim()}|$fileName|$fileSize'
      : '$fileName|$fileSize';
  final digest = sha1.convert(utf8.encode(key)).toString();
  return '${digest.substring(0, 16)}_$fileSize';
}

/// Send a file via HTTP POST, with resume support.
/// If a previous partial transfer exists on the receiver, only the remaining
/// bytes are sent. Supports [cancelToken] for mid-stream cancellation.
///
/// [onConnected] fires (at most once) when the POST handshake actually opens
/// a TCP socket to the receiver — i.e. `client.postUrl(uri)` returns without
/// throwing. Callers use this to decide whether a reverse-pull fallback is
/// appropriate: if we already had a working connection, a subsequent failure
/// is an active reject (e.g. peer cancellation) and re-publishing the file
/// via reverse-pull is pointless.
///
/// Note: the transfer-status probe is intentionally NOT used as a connection
/// signal here — `queryTransferStatus` silently swallows connection errors
/// and returns 0 on failure, so a "success" return cannot distinguish a true
/// reach from a network unreachable. The POST handshake is the only reliable
/// signal that we actually talked to the receiver.
Future<void> sendFileHttpSingle({
  required String url,
  required String fileName,
  required int fileSize,
  String? filePath,
  Uint8List? bytes,
  void Function(int sent, int total)? onProgress,
  void Function()? onConnected,
  CancelToken? cancelToken,
  String? fromDeviceId,
  String? toDeviceId,
  int? lastModifiedMs,
  String? localId,
}) async {
  if (cancelToken?.isCancelled == true) return;

  final fileId = makeFileId(fileName, fileSize, localId: localId);

  bool reportedConnected = false;
  void markConnected() {
    if (reportedConnected) return;
    reportedConnected = true;
    onConnected?.call();
  }

  int offset = 0;
  try {
    offset = await queryTransferStatus(url, fileId);
    if (offset >= fileSize) {
      onProgress?.call(fileSize, fileSize);
      return;
    }
  } catch (_) {
    offset = 0;
  }

  if (cancelToken?.isCancelled == true) return;

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  client.findProxy = (uri) => 'DIRECT';

  cancelToken?.onCancel(() {
    // Tell the receiver to abort its upload handler before tearing the socket
    // down. Closing the TCP connection alone leaves the receiver waiting for
    // the next chunk until the iterator read timeout fires, which manifests
    // as a "still receiving" bubble on the peer for several seconds.
    unawaited(notifyCancelUpload(url, fileId: fileId, fileName: fileName));
    client.close(force: true);
  });

  try {
    final uri = Uri.parse('$url/transfer');
    final request = await client.postUrl(uri);
    markConnected();
    request.headers
      ..set('X-File-Name', Uri.encodeComponent(fileName))
      ..set('X-File-Size', fileSize.toString())
      ..set(TransferProtocol.headerFileId, fileId)
      ..contentType = ContentType.binary;
    if (fromDeviceId != null && fromDeviceId.isNotEmpty) {
      request.headers.set(TransferProtocol.headerFromDeviceId, fromDeviceId);
    }
    if (toDeviceId != null && toDeviceId.isNotEmpty) {
      request.headers.set(TransferProtocol.headerToDeviceId, toDeviceId);
    }
    if (localId != null && localId.isNotEmpty) {
      request.headers.set(TransferProtocol.headerLocalId, localId);
    }
    final mtimeMs = lastModifiedMs ?? readMtimeMs(filePath);
    if (mtimeMs != null) {
      request.headers.set(
        TransferProtocol.headerFileMtimeMs,
        mtimeMs.toString(),
      );
    }
    if (offset > 0) {
      request.headers.set(
        TransferProtocol.headerResumeOffset,
        offset.toString(),
      );
    }
    request.contentLength = fileSize - offset;
    request.bufferOutput = false;

    int sent = offset;
    onProgress?.call(sent, fileSize);

    if (filePath != null) {
      final fileStream = File(filePath).openRead(offset);
      final progressStream = fileStream.map((chunk) {
        if (cancelToken?.isCancelled == true) {
          throw Exception('cancelled');
        }
        sent += chunk.length;
        onProgress?.call(sent, fileSize);
        return chunk;
      });
      await request.addStream(progressStream);
    } else if (bytes != null) {
      for (
        int i = offset;
        i < bytes.length;
        i += TransferProtocol.readBlockSize
      ) {
        if (cancelToken?.isCancelled == true) break;
        final end = math.min(i + TransferProtocol.readBlockSize, bytes.length);
        request.add(Uint8List.sublistView(bytes, i, end));
        await request.flush();
        sent += end - i;
        onProgress?.call(sent, fileSize);
      }
    }

    if (cancelToken?.isCancelled == true) {
      throw Exception('cancelled');
    }

    final response = await request.close().timeout(const Duration(seconds: 30));
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Server returned ${response.statusCode}', uri: uri);
    }
    onProgress?.call(fileSize, fileSize);
  } finally {
    client.close();
  }
}

/// Probe the receiver via HTTP GET /probe.
Future<bool> probeHttp(
  String httpUrl, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final client = HttpClient();
  try {
    client.connectionTimeout = timeout;
    final uri = Uri.parse('$httpUrl/probe');
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(timeout);
    await response.drain<void>();
    return response.statusCode == HttpStatus.ok;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}

/// Result of a successful HTTP pull. Carries the resolved [messageId] so the
/// caller can write a `received_files` index row keyed identically to the
/// chat bubble.
class PullFileResult {
  PullFileResult({
    required this.filePath,
    required this.fileName,
    required this.messageId,
    this.lastModifiedMs,
  });
  final String filePath;
  final String fileName;
  final String messageId;
  final int? lastModifiedMs;
}

/// Pull (download) a file from a sender via HTTP GET with resume support.
/// If [existingFilePath] is provided and the file exists, a Range request
/// is issued to resume from the current file size.
/// Returns the local file path where the file was saved.
///
/// [onFilePathReady] is invoked exactly once with the on-disk path the sink
/// will write to, immediately after we resolve it (either the resumed path
/// or a freshly minted unique path). Callers can use this to record the
/// partial file location BEFORE the stream finishes, so a mid-stream failure
/// (sender cancel, network drop) still leaves them with the path needed to
/// resume on the next retry.
Future<PullFileResult> pullFileHttp({
  required String downloadUrl,
  required String savePath,
  void Function(String fileName, int received, int total)? onProgress,
  String? existingFilePath,
  CancelToken? cancelToken,
  String? senderLocalId,
  void Function(String filePath)? onFilePathReady,
}) async {
  if (cancelToken?.isCancelled == true) {
    throw Exception('已取消');
  }
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  cancelToken?.onCancel(() {
    try {
      client.close(force: true);
    } catch (_) {}
  });
  try {
    int offset = 0;
    String? resumePath = existingFilePath;
    if (resumePath != null) {
      final existing = File(resumePath);
      if (await existing.exists()) {
        offset = await existing.length();
      } else {
        resumePath = null;
      }
    }

    final uri = Uri.parse(downloadUrl);
    final request = await client.getUrl(uri);
    if (offset > 0) {
      request.headers.set('Range', 'bytes=$offset-');
    }
    final response = await request.close().timeout(const Duration(seconds: 15));

    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw HttpException('Server returned ${response.statusCode}', uri: uri);
    }

    final fileName = response.headers.value('X-File-Name') != null
        ? Uri.decodeComponent(response.headers.value('X-File-Name')!)
        : 'received';
    final diskName = sanitizeFileNameForLocalStorage(fileName);
    final fileSize =
        int.tryParse(response.headers.value('X-File-Size') ?? '') ?? 0;
    final pullSenderMtimeMs = parseMtimeMs(
      response.headers.value(TransferProtocol.headerFileMtimeMs),
    );

    // Use the sender-supplied localId from the offer payload so the receiver's
    // bubble, the received_files row and the eventual Centrifugo `file`
    // publication all share the same key. Without it (older peers) we mint a
    // fresh UUID so every pull still gets a unique id — never derive from
    // fileName.
    final messageId = (senderLocalId != null && senderLocalId.isNotEmpty)
        ? 'lan_recv_pull_$senderLocalId'
        : 'lan_recv_pull_${const Uuid().v4()}';
    final perFileDir = '$savePath/$messageId';
    Directory(perFileDir).createSync(recursive: true);

    late String filePath;
    late FileMode writeMode;

    if (response.statusCode == HttpStatus.partialContent &&
        resumePath != null) {
      filePath = resumePath;
      writeMode = FileMode.append;
    } else {
      offset = 0;
      filePath = _resolveUniquePathSync(perFileDir, diskName);
      writeMode = FileMode.write;
    }

    // Expose the resolved path to the caller before we start writing so a
    // mid-stream failure still leaves them with the partial location.
    try {
      onFilePathReady?.call(filePath);
    } catch (_) {}

    final sink = File(filePath).openWrite(mode: writeMode);
    int received = offset;
    bool sinkClosed = false;
    Future<void> closeSink() async {
      if (sinkClosed) return;
      sinkClosed = true;
      try {
        await sink.close();
      } catch (_) {}
    }

    try {
      await for (final chunk in response) {
        if (cancelToken?.isCancelled == true) {
          await closeSink();
          throw Exception('已取消');
        }
        sink.add(chunk);
        received += chunk.length;
        if (fileSize > 0) {
          onProgress?.call(fileName, received, fileSize);
        }
      }
    } finally {
      // Always flush the sink — without this a sender-side disconnect or
      // network error leaves the partial bytes buffered (unwritten), and the
      // next retry's Range request would see a stale on-disk length and
      // resume from the wrong offset.
      await closeSink();
    }
    return PullFileResult(
      filePath: filePath,
      fileName: fileName,
      messageId: messageId,
      lastModifiedMs: pullSenderMtimeMs,
    );
  } finally {
    client.close();
  }
}

String _timestampSync() {
  final now = DateTime.now();
  return '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Synchronous "resolve unique filename" — kept inline here so isolate code
/// has no dependency on the main FileStore (which uses path_provider).
String _resolveUniquePathSync(String dir, String originalName) {
  final base = originalName.isEmpty ? 'received' : originalName;
  final candidate = p.join(dir, base);
  if (!File(candidate).existsSync()) return candidate;
  final dotIdx = base.lastIndexOf('.');
  final hasExt = dotIdx > 0 && dotIdx < base.length - 1;
  final stem = hasExt ? base.substring(0, dotIdx) : base;
  final ext = hasExt ? base.substring(dotIdx) : '';
  for (int i = 1; i < 10000; i++) {
    final next = p.join(dir, '$stem ($i)$ext');
    if (!File(next).existsSync()) return next;
  }
  return p.join(dir, '$stem ${DateTime.now().millisecondsSinceEpoch}$ext');
}
