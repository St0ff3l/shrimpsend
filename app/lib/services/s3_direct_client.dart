import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../logger.dart';
import 's3_config_cache.dart';
import 's3_object_url.dart';
import 'aws_v4_signer.dart';

/// Lightweight S3 client that talks directly to S3 (no backend proxy).
class S3DirectClient {
  final S3LocalConfig config;
  late final AwsV4Signer _signer;

  S3DirectClient(this.config) {
    _signer = AwsV4Signer(
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
      region: config.region,
    );
  }

  static Future<S3DirectClient?> create() async {
    final cfg = await S3ConfigCache.instance.load();
    if (cfg == null) return null;
    return S3DirectClient(cfg);
  }

  // ── Key Generation ──────────────────────────────────────────────

  String generateKey(String fileName) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
    // Strip the extension from the base name, sanitize to alphanumeric/dash/underscore,
    // then append the original extension. This avoids special-character encoding
    // mismatches between different S3-compatible providers.
    final baseName = ext.isNotEmpty
        ? fileName.substring(0, fileName.length - ext.length)
        : fileName;
    final safeBase = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '_');
    return 'uploads/$ts-$safeBase$ext';
  }

  // ── Presigned URLs (for upload/download without auth headers) ──

  Uri presignPutUrl(String key, {int expireSeconds = 3600}) {
    final uri = _objectUri(key);
    return _signer.presignUrl(
      method: 'PUT',
      uri: uri,
      expireSeconds: expireSeconds,
    );
  }

  Uri presignGetUrl(String key, {int expireSeconds = 3600}) {
    final uri = _objectUri(key);
    return _signer.presignUrl(
      method: 'GET',
      uri: uri,
      expireSeconds: expireSeconds,
    );
  }

  // ── Multipart Upload ───────────────────────────────────────────

  /// Initiate a multipart upload. Returns (uploadId, key).
  Future<({String uploadId, String key})> initiateMultipartUpload(
    String key, {
    String contentType = 'application/octet-stream',
  }) async {
    final uri = _objectUri(key).replace(queryParameters: {'uploads': ''});
    final headers = _signer.signRequest(
      method: 'POST',
      uri: uri,
      headers: {'content-type': contentType},
    );
    headers['content-type'] = contentType;

    final resp = await http.post(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'initiateMultipartUpload failed: ${resp.statusCode} ${resp.body}',
      );
    }

    final doc = XmlDocument.parse(resp.body);
    final uploadId = doc.findAllElements('UploadId').first.innerText;
    logChat.info('S3Direct: initiated multipart upload=$uploadId key=$key');
    return (uploadId: uploadId, key: key);
  }

  /// Generate a presigned PUT URL for a specific part.
  Uri presignUploadPartUrl(
    String key,
    String uploadId,
    int partNumber, {
    int expireSeconds = 3600,
  }) {
    final uri = _objectUri(key).replace(
      queryParameters: {
        'partNumber': partNumber.toString(),
        'uploadId': uploadId,
      },
    );
    return _signer.presignUrl(
      method: 'PUT',
      uri: uri,
      expireSeconds: expireSeconds,
    );
  }

  /// Complete a multipart upload.
  Future<void> completeMultipartUpload(
    String key,
    String uploadId,
    List<({int partNumber, String etag})> parts,
  ) async {
    final xmlBody = _buildCompleteXml(parts);
    final bodyBytes = utf8.encode(xmlBody);

    final uri = _objectUri(
      key,
    ).replace(queryParameters: {'uploadId': uploadId});
    final headers = _signer.signRequest(
      method: 'POST',
      uri: uri,
      headers: {'content-type': 'application/xml'},
      body: bodyBytes,
    );
    headers['content-type'] = 'application/xml';

    final resp = await http.post(uri, headers: headers, body: bodyBytes);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'completeMultipartUpload failed: ${resp.statusCode} ${resp.body}',
      );
    }
    logChat.info('S3Direct: completed multipart upload=$uploadId');
  }

  /// Abort a multipart upload.
  Future<void> abortMultipartUpload(String key, String uploadId) async {
    final uri = _objectUri(
      key,
    ).replace(queryParameters: {'uploadId': uploadId});
    final headers = _signer.signRequest(method: 'DELETE', uri: uri);

    final resp = await http.delete(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      logChat.warning('abortMultipartUpload failed: ${resp.statusCode}');
    }
    logChat.info('S3Direct: aborted multipart upload=$uploadId');
  }

  // ── Helpers ────────────────────────────────────────────────────

  /// Build object URI with path segments percent-encoded so the request path
  /// matches the canonical path used in AWS Signature V4 (avoids SignatureDoesNotMatch).
  Uri _objectUri(String key) {
    return buildS3ObjectUri(
      endpoint: config.normalizedEndpoint,
      bucket: config.bucket,
      key: key,
      pathStyleAccessEnabled: config.pathStyleAccessEnabled,
    );
  }

  String _buildCompleteXml(List<({int partNumber, String etag})> parts) {
    final buf = StringBuffer();
    buf.write('<CompleteMultipartUpload>');
    for (final p in parts) {
      buf.write('<Part>');
      buf.write('<PartNumber>${p.partNumber}</PartNumber>');
      buf.write('<ETag>${p.etag}</ETag>');
      buf.write('</Part>');
    }
    buf.write('</CompleteMultipartUpload>');
    return buf.toString();
  }
}
