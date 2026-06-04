import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../config/env.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../services/app_update_service.dart';
import '../ui/app_ui.dart';
import '../utils/toast.dart';

const _apkInstallChannel = MethodChannel('dev.ultrasend/apk');

/// Shows "new version" dialog with current vs remote version, [稍后], [不再提示此版本], and primary action.
///
/// The close (X) button only dismisses without persisting [AppUpdateService.dismissVersion].
///
/// On Android, [下载] closes this dialog and opens a **download progress** dialog (with background
/// download + install when complete). iOS still uses [onIosStore].
Future<void> showAppUpdateAvailableDialog({
  required BuildContext context,
  required UpdateInfo info,
  required AppUpdateService service,
  required bool barrierDismissible,
  required Future<void> Function() onIosStore,
}) async {
  // Play 包：更新由 Google Play 处理，应用内不再弹「发现新版本」对话框（防御）。
  if (Platform.isAndroid && Env.androidPlayDistribution) return;
  final pkg = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  final theme = Theme.of(context);
  final colors = context.appColors;
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return;
  final isIos = Platform.isIOS;
  final hasAndroidUrl = info.downloadUrl.isNotEmpty;
  final hasIosUrl = info.iosStoreUrl.isNotEmpty;
  if (isIos && !hasIosUrl && !hasAndroidUrl) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        titlePadding: AppDialog.titlePadding,
        contentPadding: AppDialog.confirmContentPadding,
        actionsPadding: AppDialog.actionsPadding,
        title: Row(
          children: [
            Expanded(
              child: Text(l10n.appUpdateTitleNewVersion),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 20),
              onPressed: () => Navigator.of(ctx).pop(),
              style: IconButton.styleFrom(
                foregroundColor: colors.textTertiary,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appUpdateCurrentVersion(pkg.version, pkg.buildNumber),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.appUpdateNewVersion(info.version, '${info.buildNumber}'),
                style: theme.textTheme.bodyLarge,
              ),
              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(info.releaseNotes, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.appUpdateLater),
          ),
          TextButton(
            onPressed: () async {
              await service.dismissVersion(info.version);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(l10n.appUpdateDontShowAgainVersion),
          ),
          if (Platform.isAndroid && hasAndroidUrl)
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Future<void>.delayed(Duration.zero);
                if (!context.mounted) return;
                await showAppUpdateDownloadProgressDialog(
                  context: context,
                  info: info,
                  service: service,
                );
              },
              child: Text(l10n.appUpdateDownload),
            )
          else if (isIos && hasIosUrl)
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await onIosStore();
              },
              child: Text(l10n.appUpdateGoAppStore),
            ),
        ],
      );
    },
  );
}

/// Download progress → complete: shows target version, package file name, [后台下载], then [安装].
Future<void> showAppUpdateDownloadProgressDialog({
  required BuildContext context,
  required UpdateInfo info,
  required AppUpdateService service,
}) async {
  if (!Platform.isAndroid) return;
  if (Env.androidPlayDistribution) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AppUpdateDownloadProgressDialog(
      info: info,
      service: service,
    ),
  );
}

class _AppUpdateDownloadProgressDialog extends StatefulWidget {
  const _AppUpdateDownloadProgressDialog({
    required this.info,
    required this.service,
  });

  final UpdateInfo info;
  final AppUpdateService service;

  @override
  State<_AppUpdateDownloadProgressDialog> createState() =>
      _AppUpdateDownloadProgressDialogState();
}

class _AppUpdateDownloadProgressDialogState
    extends State<_AppUpdateDownloadProgressDialog> {
  bool _started = false;

  void _onService() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_onService);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDownloadStarted());
  }

  void _ensureDownloadStarted() {
    if (_started || !mounted) return;
    final s = widget.service.state.value;
    final sameVersionCached = s.status == UpdateStatus.downloaded &&
        s.downloadedVersion == widget.info.version &&
        s.downloadedPath != null;
    if (sameVersionCached) {
      _started = true;
      return;
    }
    _started = true;
    widget.service.downloadApk(
      widget.info.downloadUrl,
      version: widget.info.version,
    );
  }

  @override
  void dispose() {
    widget.service.state.removeListener(_onService);
    super.dispose();
  }

  String get _fileBasename =>
      AppUpdateService.apkBasenameForVersion(widget.info.version);

  Future<void> _installFromPath(String filePath) async {
    final loc = AppLocalizations.of(context);
    Analytics.track(AnalyticsEvents.appUpdateInstallClicked, {
      'platform': 'android',
      'version': widget.info.version,
    });
    try {
      final installPath = await AppUpdateService.pathForInstall(filePath);
      final res = await _apkInstallChannel.invokeMethod<Object?>('installApk', {
        'filePath': installPath,
      });
      if (!mounted) return;
      if (res == true) {
        Navigator.of(context).pop();
      } else if (res == null) {
        AppToast.show(
          context,
          message: loc.snackbarAllowInstallUnknownApps,
          duration: const Duration(seconds: 3),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'PERMISSION_REQUIRED') {
        AppToast.show(
          context,
          message: loc.snackbarAllowInstallUnknownApps,
          duration: const Duration(seconds: 3),
        );
      } else {
        AppToast.show(
          context,
          message: loc.settingsInstallFailed(e.message ?? ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final s = widget.service.state.value;

    final title = s.status == UpdateStatus.downloaded
        ? l10n.appUpdateDownloadCompleteTitle
        : l10n.appUpdateDownloadProgressTitle;

    Widget content;
    if (s.status == UpdateStatus.error) {
      content = Text(
        s.errorMessage ?? l10n.updateStatusCheckFailed,
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.danger),
      );
    } else if (s.status == UpdateStatus.downloaded &&
        s.downloadedPath != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appUpdateDownloadedVersionLabel(
              widget.info.version,
              '${widget.info.buildNumber}',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.appUpdateDownloadedFileLabel(p.basename(s.downloadedPath!)),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    } else {
      final pct = (s.progress * 100).clamp(0.0, 100.0);
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appUpdateDownloadedVersionLabel(
              widget.info.version,
              '${widget.info.buildNumber}',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appUpdateDownloadedFileLabel(_fileBasename),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: s.status == UpdateStatus.downloading
                ? (s.progress > 0 ? s.progress : null)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.updateStatusDownloadingPercent(pct.toStringAsFixed(0)),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      titlePadding: AppDialog.titlePadding,
      contentPadding: AppDialog.confirmContentPadding,
      actionsPadding: AppDialog.actionsPadding,
      title: Text(title),
      content: SingleChildScrollView(child: content),
      actions: [
        if (s.status == UpdateStatus.downloading)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppToast.show(
                context,
                message: l10n.appUpdateDownloadProgressBackgroundToast,
                duration: const Duration(seconds: 4),
              );
            },
            child: Text(l10n.appUpdateDownloadProgressBackground),
          ),
        if (s.status == UpdateStatus.error) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.appUpdateLater),
          ),
          FilledButton(
            onPressed: () {
              widget.service.downloadApk(
                widget.info.downloadUrl,
                version: widget.info.version,
              );
            },
            child: Text(l10n.appUpdateDownloadRetry),
          ),
        ],
        if (s.status == UpdateStatus.downloaded && s.downloadedPath != null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.appUpdateLater),
          ),
          FilledButton(
            onPressed: () => _installFromPath(s.downloadedPath!),
            child: Text(l10n.mobileUpdateInstall),
          ),
        ],
      ],
    );
  }
}

/// Install prompt after APK download: shows current app version and pending package version.
///
/// [不再提示] calls [AppUpdateService.dismissPendingInstallForVersion] so this version is not
/// prompted again after restart (same SP as the "发现新版本" flow).
Future<void> showAppInstallReadyDialog({
  required BuildContext context,
  required AppUpdateService service,
  required String? pendingPackageVersion,
  required Future<void> Function() onInstall,
}) async {
  final pkg = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  final colors = context.appColors;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        titlePadding: AppDialog.titlePadding,
        contentPadding: AppDialog.confirmContentPadding,
        actionsPadding: AppDialog.actionsPadding,
        title: Row(
          children: [
            Expanded(
              child: Text(l10n.appUpdateInstallTitle),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 20),
              onPressed: () => Navigator.of(ctx).pop(),
              style: IconButton.styleFrom(
                foregroundColor: colors.textTertiary,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        content: Text(
          l10n.appUpdateInstallBody(
            pkg.version,
            pkg.buildNumber,
            pendingPackageVersion ?? l10n.appUpdateUnknownVersion,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final v = pendingPackageVersion;
              if (v != null && v.isNotEmpty) {
                await service.dismissPendingInstallForVersion(v);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(l10n.appUpdateDontShowAgain),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              Analytics.track(AnalyticsEvents.appUpdateInstallClicked, {
                'platform': 'android',
                'version': pendingPackageVersion ?? '',
              });
              await onInstall();
            },
            child: Text(l10n.appUpdateInstall),
          ),
        ],
      );
    },
  );
}

Future<void> launchExternalUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}
