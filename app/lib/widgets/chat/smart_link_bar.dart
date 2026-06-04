import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../network/link_models.dart';
import '../../network/link_recommender.dart';
import '../../providers/device_provider.dart';
import '../../ui/app_ui.dart';

/// 会话顶部智能链路提示条（绿 / 黄 / 灰）；可选 [footer] 用于附加链路操作。
class SmartLinkBar extends ConsumerWidget {
  const SmartLinkBar({
    super.key,
    this.footer,
    this.connectionTitle,
    this.connectionSubtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.embedded = false,
  });

  /// 置于主条下方的操作区。
  final Widget? footer;
  final String? connectionTitle;
  final String? connectionSubtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDeviceIdProvider);
    final rec = ref.watch(linkRecommendationProvider);
    final theme = Theme.of(context);
    final colors = context.appColors;

    Widget? mainBar;
    if (selected != null && selected != s3VirtualDeviceId && rec != null) {
      final (bg, border, icon, iconColor) = switch (rec.uiTone) {
        SmartLinkUiTone.optimal => (
          colors.successSurface.withValues(alpha: 0.85),
          colors.success.withValues(alpha: 0.35),
          LucideIcons.wifi,
          colors.success,
        ),
        SmartLinkUiTone.suggest => (
          colors.warningSurface.withValues(alpha: 0.9),
          colors.warning.withValues(alpha: 0.4),
          LucideIcons.zap,
          colors.warning,
        ),
        SmartLinkUiTone.neutral => (
          colors.surfaceMuted.withValues(alpha: 0.9),
          colors.border.withValues(alpha: 0.5),
          LucideIcons.cloud,
          colors.textTertiary,
        ),
      };

      final primary = (connectionTitle != null && connectionTitle!.isNotEmpty)
          ? connectionTitle!
          : rec.title;
      final secondary =
          (connectionSubtitle != null && connectionSubtitle!.isNotEmpty)
          ? connectionSubtitle
          : null;

      mainBar = Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: embedded ? 0 : AppSpacing.sm,
          vertical: embedded ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: embedded ? Colors.transparent : bg,
          border: embedded
              ? null
              : Border(bottom: BorderSide(color: border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                secondary == null ? primary : '$primary · $secondary',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (primaryActionLabel != null && onPrimaryAction != null)
              TextButton(
                onPressed: onPrimaryAction,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                ),
                child: Text(
                  primaryActionLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (mainBar == null && footer == null) {
      return const SizedBox.shrink();
    }
    if (footer == null) return mainBar!;
    if (mainBar == null) return footer!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        mainBar,
        if (footer != null) ...[const SizedBox(height: 4), footer!],
      ],
    );
  }
}
