import 'package:flutter/material.dart';
import 'package:flutter_desktop_updater/flutter_desktop_updater.dart' as desk;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/app_ui.dart';

/// 中文桌面更新条，使用主题色；逻辑仍由 [desk.UpdateManager] 驱动。
///
/// [navigatorKey] 用于 `showDialog`：banner 被挂在 `MaterialApp` 之外（与 Navigator 同层），
/// 自身 context 没有 Navigator ancestor，需要通过外部 navigatorKey 拿到 root navigator 的 context。
class AppDesktopUpdateBanner extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const AppDesktopUpdateBanner({super.key, this.navigatorKey});

  /// 桌面主题里 FilledButton 常见 `minimumSize.width == infinity`；放在外层 [Row] 里尾随位置时会收到水平无界约束，导致 layout 断言失败。
  static final ButtonStyle _compactFilledStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 44),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static final ButtonStyle _compactTextStyle = TextButton.styleFrom(
    minimumSize: const Size(0, 44),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static String _sizeLine(AppLocalizations l10n, int fileSizeBytes) {
    if (fileSizeBytes <= 0) return l10n.desktopUpdateSizeUnknown;
    final mb = fileSizeBytes / (1024 * 1024);
    if (mb >= 0.05) {
      return l10n.desktopUpdateSizeMb(mb.toStringAsFixed(1));
    }
    final kb = fileSizeBytes / 1024;
    return l10n.desktopUpdateSizeKb(kb.toStringAsFixed(0));
  }

  /// 叠在 [ThemeData.scaffoldBackgroundColor] 上，避免高透主色透出桌面窗口底色。
  static (Color surface, Color border) _primaryTintCardColors(ThemeData theme) {
    final base = theme.scaffoldBackgroundColor;
    return (
      Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: 0.08), base),
      Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: 0.28), base),
    );
  }

  void _showReleaseNotes(
    BuildContext context,
    AppLocalizations l10n,
    String version,
    String? notes,
  ) {
    final body = (notes ?? '').trim();
    // 优先使用外部 navigatorKey 解析 root navigator context；缺失时回退到当前 context（必须自身可达 Navigator）。
    final dialogContext = navigatorKey?.currentContext ?? context;
    showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        final dialogColors = ctx.appColors;
        return AlertDialog(
          titlePadding: AppDialog.titlePadding,
          contentPadding: AppDialog.contentPadding,
          actionsPadding: AppDialog.actionsPadding,
          title: Text(l10n.desktopUpdateReleaseNotesTitle(version)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
            child: SingleChildScrollView(
              child: SelectableText(
                body.isEmpty ? l10n.desktopUpdateReleaseNotesEmpty : body,
                style: dialogTheme.textTheme.bodyMedium?.copyWith(
                  color: body.isEmpty ? dialogColors.textSecondary : dialogColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.desktopUpdateClose),
            ),
          ],
        );
      },
    );
  }

  Widget _releaseNotesLink(
    BuildContext context,
    AppLocalizations l10n,
    desk.UpdateInfo info,
  ) {
    if (info.releaseNotes.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: theme.colorScheme.primary,
            visualDensity: VisualDensity.compact,
            textStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          icon: const Icon(LucideIcons.fileText, size: 14),
          label: Text(l10n.desktopUpdateReleaseNotesAction),
          onPressed: () => _showReleaseNotes(
            context,
            l10n,
            info.version,
            info.releaseNotes,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: desk.UpdateManager(),
      builder: (context, _) {
        final theme = Theme.of(context);
        final colors = context.appColors;
        final l10n = AppLocalizations.of(context);
        final manager = desk.UpdateManager();

        return switch (manager.status) {
          desk.UpdateStatus.updateAvailable =>
            _available(context, theme, colors, l10n, manager),
          desk.UpdateStatus.updating =>
            _updating(context, theme, colors, l10n, manager.progress),
          desk.UpdateStatus.readyToRestart =>
            _readyRestart(context, theme, colors, l10n, manager),
          desk.UpdateStatus.restarting =>
            _restarting(context, theme, colors, l10n),
          desk.UpdateStatus.error =>
            _error(context, theme, colors, l10n, manager),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _available(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
    desk.UpdateManager manager,
  ) {
    final info = manager.updateInfo!;
    final (surface, border) = _primaryTintCardColors(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppRadius.small,
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.download, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.desktopUpdateBannerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.desktopUpdateBannerSubtitle(
                      info.version,
                      _sizeLine(l10n, info.fileSize),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  _releaseNotesLink(context, l10n, info),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  style: _compactTextStyle,
                  onPressed: manager.dismiss,
                  child: Text(l10n.desktopUpdateLater),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  style: _compactFilledStyle,
                  onPressed: manager.startUpdate,
                  child: Text(l10n.desktopUpdateNow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _updating(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
    double progress,
  ) {
    final (surface, border) = _primaryTintCardColors(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppRadius.small,
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, value: progress),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.desktopUpdateDownloading,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: progress > 0 ? progress : null),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restarting(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
  ) {
    final (surface, border) = _primaryTintCardColors(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppRadius.small,
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.desktopUpdateApplying,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _readyRestart(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
    desk.UpdateManager manager,
  ) {
    final surface = colors.successSurface;
    final border = colors.success.withValues(alpha: 0.35);
    final info = manager.updateInfo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppRadius.small,
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.circleCheck, color: colors.success, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.desktopUpdateReadyTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.desktopUpdateReadyBody,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  if (info != null) _releaseNotesLink(context, l10n, info),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonal(
                  style: _compactFilledStyle,
                  onPressed: () => manager.restartApp(),
                  child: Text(l10n.desktopUpdateQuitRestart),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
    desk.UpdateManager manager,
  ) {
    final surface = colors.dangerSurface;
    final border = colors.danger.withValues(alpha: 0.35);
    final msg = manager.error ?? l10n.desktopUpdateErrorUnknown;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppRadius.small,
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.circleAlert, color: colors.danger, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.desktopUpdateCheckFailedTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  style: _compactTextStyle,
                  onPressed: manager.dismiss,
                  child: Text(l10n.desktopUpdateClose),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  style: _compactFilledStyle,
                  onPressed: () => manager.checkForUpdate(),
                  child: Text(l10n.desktopUpdateRetry),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
