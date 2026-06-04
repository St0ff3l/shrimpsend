/// Builds object URIs for SigV4 signing and direct S3 requests.
Uri buildS3ObjectUri({
  required String endpoint,
  required String bucket,
  required String key,
  bool pathStyleAccessEnabled = true,
}) {
  final base = endpoint.replaceFirst(RegExp(r'/$'), '');
  final pathStyle = pathStyleAccessEnabled;
  final segments = pathStyle ? [bucket, ...key.split('/')] : key.split('/');
  final encodedPath =
      '/' + segments.map((s) => Uri.encodeComponent(s)).join('/');

  if (pathStyle) {
    return Uri.parse('$base$encodedPath');
  }

  final endpointUri = Uri.parse(base.contains('://') ? base : 'https://$base');
  final bucketPrefix = '$bucket.';
  final host = endpointUri.host.startsWith(bucketPrefix)
      ? endpointUri.host
      : bucketPrefix + endpointUri.host;
  return endpointUri.replace(
    host: host,
    path: encodedPath,
    query: '',
    fragment: '',
  );
}
