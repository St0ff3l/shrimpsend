import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/file_export_service.dart';
import 'toast.dart';

Future<void> runSaveFileAs({
  required BuildContext context,
  required AppLocalizations l10n,
  required String sourcePath,
  required String fileName,
}) async {
  try {
    final result = await FileExportService.saveFileAs(
      sourcePath: sourcePath,
      fileName: fileName,
      dialogTitle: l10n.fileExportSaveAsDialogTitle,
    );
    if (!context.mounted) return;
    if (result == null) return;
    if (result.usedShareFallback) {
      AppToast.show(context, message: l10n.fileExportOpenedShareSheet);
      return;
    }
    AppToast.show(context, message: l10n.fileExportSavedAs(result.displayName));
  } catch (_) {
    if (!context.mounted) return;
    AppToast.show(context, message: l10n.fileExportFailed);
  }
}

String saveAsActionLabel(AppLocalizations l10n) => l10n.fileExportSaveAs;
