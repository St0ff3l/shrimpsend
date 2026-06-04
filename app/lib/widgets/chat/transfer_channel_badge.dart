import 'package:flutter/material.dart';

import '../../color_theme.dart';
import '../../ui/app_ui.dart';

/// Pill label for HTTP(LAN) / WebRTC / S3 on file transfer bubbles.
class TransferChannelBadge extends StatelessWidget {
  const TransferChannelBadge({
    super.key,
    required this.transferType,
    /// LAN pill uses [AppColorTheme.lanColor], same as emerald sent bubbles — use lift for readability.
    this.liftOnTintedSentBubble = false,
  });

  final String? transferType;

  final bool liftOnTintedSentBubble;

  @override
  Widget build(BuildContext context) {
    final label = switch (transferType) {
      'lan' => 'HTTP',
      'webrtc' => 'WebRTC',
      's3' => 'S3',
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final base = AppColorTheme.protocolColor(transferType);
    final bgAlpha = brightness == Brightness.dark ? 0.32 : 0.14;

    final useLanLift = liftOnTintedSentBubble && transferType == 'lan';
    final Color bgColor = useLanLift
        ? Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.35 : 0.22)
        : base.withValues(alpha: bgAlpha);
    final Color fgColor =
        useLanLift ? Colors.white : base;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: fgColor,
        ),
      ),
    );
  }
}
