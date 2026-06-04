import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/env.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../services/app_update_service.dart';
import '../services/file_store.dart';
import '../screens/file_preview_screen.dart';
import '../utils/file_utils.dart';
import '../utils/received_file_actions.dart';
import '../utils/toast.dart';
import '../widgets/app_confirm_dialog.dart';

const MethodChannel _apkChannel = MethodChannel('dev.ultrasend/apk');

/// Single entry point used by both the chat bubbles and the file manager
/// when the user taps a received file. Behaviour:
///
/// 1. If the file's category is previewable (image / video / pdf / code /
///    short text), push [FilePreviewScreen].
/// 2. If it looks like an APK and we are not on a Play-store distribution,
///    trigger the install flow.
/// 3. Otherwise prompt with the "no preview / open as text" confirm dialog
///    and, on confirm, push [FilePreviewScreen] in `forceText` mode.
///
/// Routing through [FilePreviewScreen] keeps things working on mobile,
/// where `launchUrl(Uri.file(...))` is unreliable.
Future<void> openReceivedFile(
  BuildContext context,
  ReceivedFileInfo file, {
  ReceivedFilePreviewCallbacks? callbacks,
}) async {
  if (isPreviewable(file.category, file.displayName)) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePreviewScreen(file: file, callbacks: callbacks),
      ),
    );
    Analytics.track(AnalyticsEvents.filePreviewOpen, {
      'category': file.category.name,
    });
    return;
  }
  if (looksLikeApkInstallerFileName(file.displayName)) {
    if (Env.androidPlayDistribution) {
      await _showNoPreviewDialog(context, file, callbacks: callbacks);
    } else {
      await _installApk(context, file);
    }
    return;
  }
  await _showNoPreviewDialog(context, file, callbacks: callbacks);
}

Future<void> _installApk(BuildContext context, ReceivedFileInfo file) async {
  final l10n = AppLocalizations.of(context);
  if (!Platform.isAndroid) {
    if (!context.mounted) return;
    AppToast.show(context, message: l10n.fmAndroidApkOnly);
    return;
  }
  try {
    final installPath = await AppUpdateService.pathForInstall(file.path);
    await _apkChannel.invokeMethod('installApk', {'filePath': installPath});
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    if (e.code == 'PERMISSION_REQUIRED') {
      AppToast.show(
        context,
        message: l10n.snackbarAllowInstallUnknownApps,
        duration: const Duration(seconds: 3),
      );
    } else {
      AppToast.show(
        context,
        message: l10n.settingsInstallFailed(e.message ?? ''),
      );
    }
  }
}

Future<void> _showNoPreviewDialog(
  BuildContext context,
  ReceivedFileInfo file, {
  ReceivedFilePreviewCallbacks? callbacks,
}) async {
  final l10n = AppLocalizations.of(context);
  final openAsText = await AppConfirmDialog.show(
    context,
    title: l10n.fmPreviewUnavailableTitle,
    content: l10n.fmPreviewUnavailableBody,
    confirmLabel: l10n.fmPreviewOpenAsText,
  );
  if (openAsText && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePreviewScreen(
          file: file,
          forceText: true,
          callbacks: callbacks,
        ),
      ),
    );
    Analytics.track(AnalyticsEvents.filePreviewOpen, {
      'category': file.category.name,
      'force_text': true,
    });
  }
}
