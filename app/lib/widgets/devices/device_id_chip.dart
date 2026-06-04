import 'package:flutter/material.dart';

import '../../ui/app_ui.dart';

/// Per-user 1–999 short code from server; hidden when null (e.g. LAN-only).
class DisplayCodeChip extends StatelessWidget {
  const DisplayCodeChip({
    super.key,
    required this.displayCode,
    required this.background,
    required this.foreground,
    this.borderColor,
    this.tooltipMessage,
  });

  final int? displayCode;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  /// When null, defaults to a short Chinese label + code (legacy list chips).
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    final code = displayCode;
    if (code == null) return const SizedBox.shrink();
    final border = borderColor;
    return Tooltip(
      message: tooltipMessage ?? '设备号 $code',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Text(
          '#$code',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: foreground,
            height: 1.2,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

/// Muted chip for device management list rows.
class DeviceManagementDisplayCodeChip extends StatelessWidget {
  const DeviceManagementDisplayCodeChip({
    super.key,
    required this.displayCode,
    required this.colors,
  });

  final int? displayCode;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return DisplayCodeChip(
      displayCode: displayCode,
      background: colors.surfaceMuted,
      foreground: colors.textSecondary,
      borderColor: colors.border.withValues(alpha: 0.65),
    );
  }
}
