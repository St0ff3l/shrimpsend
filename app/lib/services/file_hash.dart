import 'dart:io';

import 'package:crypto/crypto.dart';

/// Compute the SHA-256 hash of a file by streaming it in chunks.
/// Memory usage stays at O(chunk_size) regardless of file size.
Future<String> computeFileHash(String filePath) async {
  final sink = _DigestSink();
  final byteSink = sha256.startChunkedConversion(sink);

  final stream = File(filePath).openRead();
  await for (final chunk in stream) {
    byteSink.add(chunk);
  }
  byteSink.close();
  return sink.value.toString();
}

/// Compute the MD5 hash of a file by streaming it in chunks.
Future<String> computeFileMd5(String filePath) async {
  final sink = _DigestSink();
  final byteSink = md5.startChunkedConversion(sink);

  final stream = File(filePath).openRead();
  await for (final chunk in stream) {
    byteSink.add(chunk);
  }
  byteSink.close();
  return sink.value.toString();
}

/// Compute the SHA-256 hash of in-memory bytes.
String computeBytesHash(List<int> bytes) {
  return sha256.convert(bytes).toString();
}

/// Simple sink that captures the final [Digest] value from a chunked hash.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
