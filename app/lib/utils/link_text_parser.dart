/// Parses http/https and www. URLs from chat message text.
class LinkTextSegment {
  const LinkTextSegment({required this.text, this.url});

  final String text;

  /// Non-null when [text] is a clickable link.
  final String? url;

  bool get isLink => url != null;
}

abstract final class LinkTextParser {
  static final RegExp _urlPattern = RegExp(
    r"(?:https?://[\w\-._~:/?#\[\]@!$&'()*+,;=%]+|www\.[\w\-._~:/?#\[\]@!$&'()*+,;=%]+)",
    caseSensitive: false,
  );

  static const _trailingPunctuation = '.,;:!?)]}\'"，。；：！？）】》';

  /// Returns `null` when [text] contains no links.
  static List<LinkTextSegment>? parse(String text) {
    if (text.isEmpty) return null;

    final matches = _urlPattern.allMatches(text).toList();
    if (matches.isEmpty) return null;

    final segments = <LinkTextSegment>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        segments.add(LinkTextSegment(text: text.substring(cursor, match.start)));
      }

      final raw = match.group(0)!;
      final trimmed = _trimTrailingPunctuation(raw);
      final trailing = raw.substring(trimmed.length);

      segments.add(LinkTextSegment(text: trimmed, url: trimmed));
      if (trailing.isNotEmpty) {
        segments.add(LinkTextSegment(text: trailing));
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      segments.add(LinkTextSegment(text: text.substring(cursor)));
    }

    return segments;
  }

  static String _trimTrailingPunctuation(String value) {
    var end = value.length;
    while (end > 0 && _trailingPunctuation.contains(value[end - 1])) {
      end--;
    }
    return value.substring(0, end);
  }

  /// Converts a matched link to a launchable [Uri], adding https for www.
  static Uri? toLaunchUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = trimmed.toLowerCase().startsWith('www.')
        ? 'https://$trimmed'
        : trimmed;

    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    return uri;
  }
}
