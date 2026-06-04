import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../ui/app_ui.dart';

/// 统一的确认对话框，使用项目 token 与主题，用于退出登录、删除确认、S3 未配置等场景。
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String cancelLabel;
  final String confirmLabel;
  final bool isDanger;
  final IconData? icon;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelLabel = '取消',
    required this.confirmLabel,
    this.isDanger = false,
    this.icon,
  });

  /// 显示确认对话框，点击确认返回 [true]，取消返回 [false]。
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String content,
    String cancelLabel = '取消',
    required String confirmLabel,
    bool isDanger = false,
    IconData? icon,
    bool barrierDismissible = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AppConfirmDialog(
        title: title,
        content: content,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        isDanger: isDanger,
        icon: icon,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      titlePadding: AppDialog.titlePadding,
      contentPadding: AppDialog.confirmContentPadding,
      actionsPadding: AppDialog.actionsPadding,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDanger
                          ? colors.dangerSurface
                          : colors.surfaceMuted,
                      borderRadius: AppRadius.small,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: isDanger ? colors.danger : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 20),
            onPressed: () => Navigator.pop(context, false),
            style: IconButton.styleFrom(
              foregroundColor: colors.textTertiary,
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      content: Text(
        content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
          height: 1.4,
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: isDanger ? colors.danger : null,
                  foregroundColor: isDanger ? Colors.white : null,
                ),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
