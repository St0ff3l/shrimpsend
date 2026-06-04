import 'cancel_token.dart';

typedef OnTransferProgress = void Function(int transferred, int total);

class CloudUploadResult {
  final String key;
  final String fileName;
  CloudUploadResult({required this.key, required this.fileName});
}

class CloudDownloadResult {
  final String filePath;
  final int totalBytes;
  CloudDownloadResult({required this.filePath, required this.totalBytes});
}

abstract class CloudTransferService {
  Future<CloudUploadResult> upload({
    required String fileName,
    required int fileSize,
    String? filePath,
    List<int>? bytes,
    String? contentType,
    CancelToken? cancelToken,
    OnTransferProgress? onProgress,
  });

  Future<CloudDownloadResult> download({
    required String key,
    required String savePath,
    CancelToken? cancelToken,
    OnTransferProgress? onProgress,
    int? lastModifiedMs,
  });
}
