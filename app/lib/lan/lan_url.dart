/// Builds a canonical `http://` base URL for [host] and [port].
///
/// IPv6 literals (including link-local with `%zone`) require brackets in URI
/// syntax; using [Uri] avoids invalid string concatenation like `http://fe80::1:8080`.
String buildLanHttpBaseUrl(String host, int port) {
  return Uri(scheme: 'http', host: host, port: port).toString();
}
