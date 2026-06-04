import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../utils/link_text_parser.dart';
import '../../utils/toast.dart';

class LinkableMessageText extends StatefulWidget {
  const LinkableMessageText({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.linkColor,
    required this.selectable,
  });

  final String text;
  final TextStyle? baseStyle;
  final Color linkColor;
  final bool selectable;

  @override
  State<LinkableMessageText> createState() => _LinkableMessageTextState();
}

class _LinkableMessageTextState extends State<LinkableMessageText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _openLink(String raw) async {
    final uri = LinkTextParser.toLaunchUri(raw);
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) return;

    final l10n = AppLocalizations.of(context);
    AppToast.show(context, message: l10n.legalCouldNotOpenLink);
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TextSpan _buildSpanTree() {
    _clearRecognizers();

    final segments = LinkTextParser.parse(widget.text)!;
    final linkStyle = widget.baseStyle?.copyWith(
      color: widget.linkColor,
      decoration: TextDecoration.underline,
      decorationColor: widget.linkColor,
    );

    return TextSpan(
      style: widget.baseStyle,
      children: [
        for (final segment in segments)
          if (segment.isLink)
            () {
              final url = segment.url!;
              final recognizer = TapGestureRecognizer()
                ..onTap = () => _openLink(url);
              _recognizers.add(recognizer);
              return TextSpan(
                text: segment.text,
                style: linkStyle,
                recognizer: recognizer,
              );
            }()
          else
            TextSpan(text: segment.text, style: widget.baseStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final segments = LinkTextParser.parse(widget.text);
    if (segments == null) {
      return widget.selectable
          ? SelectableText(widget.text, style: widget.baseStyle)
          : Text(widget.text, style: widget.baseStyle);
    }

    final span = _buildSpanTree();
    return widget.selectable
        ? SelectableText.rich(span)
        : Text.rich(span);
  }
}
