import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../network/connection_bar_view_model.dart';
import '../../network/link_models.dart';
import '../../providers/device_provider.dart';
import '../../ui/app_ui.dart';
import '../busy_status_indicator.dart';

class UnifiedConnectionBar extends StatelessWidget {
  const UnifiedConnectionBar({
    super.key,
    required this.model,
    this.onPrimaryAction,
    this.onRefresh,
    this.onOpenSwitchDialog,
    this.onResumeAuto,
    this.onModeSelected,
  });

  final ConnectionBarViewModel model;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onRefresh;
  final Future<void> Function()? onOpenSwitchDialog;
  final VoidCallback? onResumeAuto;

  /// 点击某一传输方式标签时直接切换（与「切换」按钮打开的对话框结果一致）。
  final Future<void> Function(SendMode mode)? onModeSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    final (
      bgColor,
      borderColor,
      leadingIcon,
      leadingColor,
    ) = switch (model.uiTone) {
      SmartLinkUiTone.optimal => (
        colors.successSurface.withValues(alpha: 0.6),
        colors.success.withValues(alpha: 0.35),
        LucideIcons.wifi,
        colors.success,
      ),
      SmartLinkUiTone.suggest => (
        colors.warningSurface.withValues(alpha: 0.6),
        colors.warning.withValues(alpha: 0.4),
        LucideIcons.zap,
        colors.warning,
      ),
      SmartLinkUiTone.neutral => (
        colors.surfaceMuted.withValues(alpha: 0.6),
        colors.border.withValues(alpha: 0.45),
        LucideIcons.cloud,
        colors.textTertiary,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(leadingIcon, size: 14, color: leadingColor),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model.title.isEmpty
                          ? l10n.connectionBarDefaultTitle
                          : model.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    if (model.subtitle.isNotEmpty)
                      Text(
                        model.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (model.manualLocked ? colors.warning : colors.success)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  model.manualLocked
                      ? l10n.connectionBarManualShort
                      : l10n.connectionBarAutoShort,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: model.manualLocked ? colors.warning : colors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (model.manualLocked && onResumeAuto != null) ...[
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  onTap: onResumeAuto,
                  child: Text(
                    l10n.connectionBarResumeAuto,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (model.primaryActionLabel != null &&
                  onPrimaryAction != null) ...[
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  onPressed: onPrimaryAction,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                  ),
                  child: Text(
                    model.primaryActionLabel!,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (onOpenSwitchDialog != null) ...[
                const SizedBox(width: AppSpacing.xs),
                FilledButton.tonal(
                  onPressed: () => unawaited(onOpenSwitchDialog!.call()),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 4,
                    ),
                  ),
                  child: Text(
                    l10n.connectionBarSwitchMode,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (onRefresh != null) ...[
                const SizedBox(width: 2),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    onPressed: model.probing ? null : onRefresh,
                    tooltip: l10n.connectionBarRefreshOnlineStatus,
                    padding: EdgeInsets.zero,
                    icon: model.probing
                        ? BusyStatusIndicator(
                            size: 13,
                            strokeWidth: 1.6,
                            color: colors.textTertiary,
                          )
                        : Icon(
                            LucideIcons.refreshCw,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: model.modeItems.map((item) {
                final primary = theme.colorScheme.primary;
                final canTap = onModeSelected != null && !item.isSelected;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: canTap
                          ? () => unawaited(onModeSelected!(item.mode))
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.isSelected
                              ? primary.withValues(alpha: 0.1)
                              : item.available
                              ? colors.surface.withValues(alpha: 0.85)
                              : colors.surface.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.isSelected
                                ? primary
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: item.isSelected
                                    ? primary
                                    : item.available
                                    ? colors.textPrimary
                                    : colors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: item.available
                                    ? colors.success
                                    : colors.textTertiary.withValues(
                                        alpha: 0.6,
                                      ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
