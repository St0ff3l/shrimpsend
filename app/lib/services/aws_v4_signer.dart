import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Lightweight AWS Signature V4 implementation for S3 requests.
/// Only depends on the `crypto` package (HMAC-SHA256 / SHA-256).
class AwsV4Signer {
  final String accessKeyId;
  final String secretAccessKey;
  final String region;
  final String service;

  AwsV4Signer({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.region,
    this.service = 's3',
  });

  /// Generate a presigned URL for the given HTTP [method] and [uri].
  /// The URL is valid for [expireSeconds] (default 3600).
  Uri presignUrl({
    required String method,
    required Uri uri,
    int expireSeconds = 3600,
    Map<String, String>? additionalHeaders,
  }) {
    final now = DateTime.now().toUtc();
    final dateStamp = _dateStamp(now);
    final amzDate = _amzDate(now);
    final scope = '$dateStamp/$region/$service/aws4_request';

    final headers = <String, String>{
      'host':
          uri.host +
          (uri.hasPort && uri.port != 443 && uri.port != 80
              ? ':${uri.port}'
              : ''),
      ...?additionalHeaders,
    };
    final signedHeadersList = headers.keys.map((k) => k.toLowerCase()).toList()
      ..sort();
    final signedHeaders = signedHeadersList.join(';');

    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    queryParams['X-Amz-Credential'] = '$accessKeyId/$scope';
    queryParams['X-Amz-Date'] = amzDate;
    queryParams['X-Amz-Expires'] = expireSeconds.toString();
    queryParams['X-Amz-SignedHeaders'] = signedHeaders;

    final sortedParams = Map.fromEntries(
      queryParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final canonicalQueryString = sortedParams.entries
        .map((e) => '${_uriEncode(e.key)}=${_uriEncode(e.value)}')
        .join('&');

    final canonicalHeaders = signedHeadersList
        .map(
          (h) =>
              '$h:${headers[h]?.trim() ?? headers[h.toLowerCase()]?.trim() ?? ''}\n',
        )
        .join();

    final canonicalRequest = [
      method.toUpperCase(),
      _uriEncodePath(uri.path.isEmpty ? '/' : uri.path),
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      _sha256Hex(utf8.encode(canonicalRequest)),
    ].join('\n');

    final signingKey = _deriveSigningKey(dateStamp);
    final signature = _hmacSha256Hex(signingKey, utf8.encode(stringToSign));

    final finalQuery = '$canonicalQueryString&X-Amz-Signature=$signature';
    return uri.replace(query: finalQuery);
  }

  /// Sign a request by adding Authorization and related headers.
  /// Returns a map of headers to merge into the HTTP request.
  Map<String, String> signRequest({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    List<int>? body,
  }) {
    final now = DateTime.now().toUtc();
    final dateStamp = _dateStamp(now);
    final amzDate = _amzDate(now);
    final scope = '$dateStamp/$region/$service/aws4_request';

    final payloadHash = body != null && body.isNotEmpty
        ? _sha256Hex(body)
        : _sha256Hex(const <int>[]);

    final allHeaders = <String, String>{
      'host':
          uri.host +
          (uri.hasPort && uri.port != 443 && uri.port != 80
              ? ':${uri.port}'
              : ''),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      ...?headers,
    };
    final signedHeadersList =
        allHeaders.keys.map((k) => k.toLowerCase()).toList()..sort();
    final signedHeaders = signedHeadersList.join(';');

    final canonicalQueryString = uri.queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final queryString = canonicalQueryString
        .map((e) => '${_uriEncode(e.key)}=${_uriEncode(e.value)}')
        .join('&');

    final canonicalHeaders = signedHeadersList
        .map((h) => '$h:${allHeaders[h]?.trim()}\n')
        .join();

    final canonicalRequest = [
      method.toUpperCase(),
      _uriEncodePath(uri.path.isEmpty ? '/' : uri.path),
      queryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      _sha256Hex(utf8.encode(canonicalRequest)),
    ].join('\n');

    final signingKey = _deriveSigningKey(dateStamp);
    final signature = _hmacSha256Hex(signingKey, utf8.encode(stringToSign));

    return {
      'Authorization':
          'AWS4-HMAC-SHA256 Credential=$accessKeyId/$scope, SignedHeaders=$signedHeaders, Signature=$signature',
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Uint8List _deriveSigningKey(String dateStamp) {
    final kDate = _hmacSha256(
      utf8.encode('AWS4$secretAccessKey'),
      utf8.encode(dateStamp),
    );
    final kRegion = _hmacSha256(kDate, utf8.encode(region));
    final kService = _hmacSha256(kRegion, utf8.encode(service));
    return _hmacSha256(kService, utf8.encode('aws4_request'));
  }

  static String _dateStamp(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

  static String _amzDate(DateTime dt) =>
      '${_dateStamp(dt)}T${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}Z';

  static Uint8List _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  static String _hmacSha256Hex(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).toString();
  }

  static String _sha256Hex(List<int> data) => sha256.convert(data).toString();

  static String _uriEncode(String value) {
    return Uri.encodeComponent(value).replaceAll('+', '%20');
  }

  static String _uriEncodePath(String path) {
    return path.split('/').map((s) => _uriEncode(s)).join('/');
  }
}
