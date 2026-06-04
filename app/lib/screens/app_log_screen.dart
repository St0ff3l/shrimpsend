import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/app_log_file.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../utils/open_directory.dart';
import '../utils/runtime_platform.dart';
import '../utils/toast.dart';

class AppLogScreen extends StatefulWidget {
  const AppLogScreen({super.key});

  @override
  State<AppLogScreen> createState() => _AppLogScreenState();
}

class _AppLogScreenState extends State<AppLogScreen> {
  List<AppLogFileEntry> _files = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!AppLogFile.instance.isAvailable) {
        if (mounted) {
          setState(() {
            _files = const [];
            _error = AppLocalizations.of(context).appLogErrorDirUnavailable;
            _loading = false;
          });
        }
        return;
      }
      final files = await AppLogFile.instance.listLogFiles();
      if (mounted) {
        setState(() {
          _files = files;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).appLogReadFailed('$e');
          _loading = false;
        });
      }
    }
  }

  Future<void> _openLogDir(BuildContext context) async {
    final dir = AppLogFile.instance.logsDirectoryPath;
    if (dir == null) {
      AppToast.show(
        context,
        message: AppLocalizations.of(context).appLogToastDirUnavailable,
      );
      return;
    }
    final ok = await openDirectoryInFileManager(dir);
    if (!context.mounted) return;
    if (!ok) {
      AppToast.show(
        context,
        message: AppLocalizations.of(context).appLogToastOpenFolderFailed,
      );
    }
  }

  String _formatSubtitle(BuildContext context, AppLogFileEntry entry) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final size = formatFileSize(entry.size);
    final modified = DateFormat.yMMMd(locale).add_Hms().format(
          entry.modified.toLocal(),
        );
    return l10n.appLogFileMeta(size, modified);
  }

  Future<void> _shareFile(AppLogFileEntry entry) async {
    await Share.shareXFiles([XFile(entry.path)]);
  }

  Future<void> _onRowTap(AppLogFileEntry entry) async {
    if (RuntimePlatform.isDesktop) {
      final l10n = AppLocalizations.of(context);
      try {
        final ok = await launchUrl(
          Uri.file(entry.path),
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (!ok) {
          AppToast.show(context, message: l10n.fmPreviewUnavailableTitle);
        }
      } catch (_) {
        if (!mounted) return;
        AppToast.show(context, message: l10n.fmPreviewUnavailableTitle);
      }
      return;
    }
    await _shareFile(entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appLogTitle),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (RuntimePlatform.isDesktop)
            IconButton(
              tooltip: l10n.appLogTooltipOpenFolder,
              icon: const Icon(LucideIcons.folderOpen),
              onPressed: () => _openLogDir(context),
            ),
          IconButton(
            tooltip: l10n.appLogTooltipRefresh,
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.danger,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _files.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          l10n.appLogEmptyHint,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSize.contentMaxWidth,
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          itemCount: _files.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: colors.border,
                            indent: AppSpacing.md + 40,
                          ),
                          itemBuilder: (context, index) {
                            final entry = _files[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              leading: Icon(
                                LucideIcons.fileText,
                                color: colors.textSecondary,
                              ),
                              title: Text(entry.name),
                              subtitle: Text(
                                _formatSubtitle(context, entry),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              onTap: () => unawaited(_onRowTap(entry)),
                              trailing: IconButton(
                                tooltip: l10n.chatMenuShare,
                                icon: const Icon(LucideIcons.share2),
                                onPressed: () => unawaited(_shareFile(entry)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}
