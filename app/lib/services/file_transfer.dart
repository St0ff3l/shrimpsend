import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../api/api.dart';
import '../lan/transfer_worker.dart';
import '../logger.dart';
import 'cancel_token.dart';

/// Callback for per-chunk progress. [sent] bytes sent so far, [total] total bytes.
typedef OnTransferProgress = void Function(int sent, int total);

/// Tries direct push via HTTP POST to each target device.
/// Returns (true if at least one succeeded, list of failed devices).
Future<(bool, List<DeviceDto>)> trySendFileViaLan(
  PlatformFile file,
  List<DeviceDto> targetDevices, {
  CancelToken? cancelToken,
  OnTransferProgress? onProgress,
  void Function()? onConnected,
  String? fromDeviceId,
  String? localId,
}) async {
  if (targetDevices.isEmpty) return (false, <DeviceDto>[]);
  if (file.path == null && file.bytes == null) {
    return (false, List<DeviceDto>.from(targetDevices));
  }
  final total = file.size;
  final failed = <DeviceDto>[];

  final Uint8List? inMemoryBytes;
  if (file.bytes != null) {
    inMemoryBytes = file.bytes is Uint8List
        ? file.bytes as Uint8List
        : Uint8List.fromList(file.bytes!);
  } else {
    inMemoryBytes = null;
  }

  for (final d in targetDevices) {
    if (cancelToken?.isCancelled == true) break;
    final url = d.lanHttpUrl;
    if (url == null || url.isEmpty) {
      failed.add(d);
      continue;
    }
    try {
      await sendFileHttpSingle(
        url: url,
        fileName: file.name,
        fileSize: total,
        filePath: file.path,
        bytes: inMemoryBytes,
        cancelToken: cancelToken,
        fromDeviceId: fromDeviceId,
        toDeviceId: d.deviceId,
        localId: localId,
        onConnected: onConnected,
        onProgress: (sent, t) {
          if (cancelToken?.isCancelled != true) {
            onProgress?.call(sent, t);
          }
        },
      );
      logChat.info('trySendFileViaLan ok to ${d.deviceId}');
    } catch (e) {
      logChat.warning('trySendFileViaLan failed to ${d.deviceId}: $e');
      failed.add(d);
    }
  }
  return (failed.length < targetDevices.length, failed);
}
