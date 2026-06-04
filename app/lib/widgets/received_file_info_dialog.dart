import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../typography.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/file_hash.dart';
import '../services/file_store.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../utils/toast.dart';

Future<void> showReceivedFileInfoDialog(
  BuildContext context,
  ReceivedFileInfo file,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => ReceivedFileInfoDialog(file: file),
  );
}

class ReceivedFileInfoDialog extends StatefulWidget {
  final ReceivedFileInfo file;

  const ReceivedFileInfoDialog({super.key, required this.file});

  @override
  State<ReceivedFileInfoDialog> createState() => _ReceivedFileInfoDialogState();
}

class _ReceivedFileInfoDialogState extends State<ReceivedFileInfoDialog> {
  int? _sizeBytes;
  DateTime? _modifiedAt;
  bool _fileExists = false;
  String? _md5;
  bool _md5Loading = true;
  bool _md5Failed = false;

  @override
  void initState() {
    super.initState();
    _loadDiskMeta();
    _loadMd5();
  }

  Future<void> _loadDiskMeta() async {
    final f = File(widget.file.path);
    if (!await f.exists()) {
      if (!mounted) return;
      setState(() {
        _sizeBytes = widget.file.size;
        _modifiedAt = widget.file.modified;
        _fileExists = false;
      });
      return;
    }
    final stat = await f.stat();
    if (!mounted) return;
    setState(() {
      _fileExists = true;
      _sizeBytes = stat.size;
      _modifiedAt = stat.modified;
    });
  }

  Future<void> _loadMd5() async {
    final f = File(widget.file.path);
    if (!await f.exists()) {
      if (!mounted) return;
      setState(() {
        _md5Loading = false;
        _md5Failed = true;
      });
      return;
    }
    try {
      final hash = await computeFileMd5(widget.file.path);
      if (!mounted) return;
      setState(() {
        _md5 = hash;
        _md5Loading = false;
        _md5Failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _md5Loading = false;
        _md5Failed = true;
      });
    }
  }

  String _formatDateTime(BuildContext context, DateTime dt) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).add_Hms().format(dt.toLocal());
  }

  String _categoryLabel(AppLocalizations l10n, FileCategory category) {
    return switch (category) {
      FileCategory.image => l10n.fmCategoryImage,
      FileCategory.video => l10n.fmCategoryVideo,
      FileCategory.audio => l10n.fmCategoryAudio,
      FileCategory.pdf => l10n.fmCategoryPdf,
      FileCategory.archive => l10n.fmCategoryArchive,
      FileCategory.document => l10n.fmCategoryDocument,
      FileCategory.code => l10n.fmCategoryCode,
      FileCategory.other => l10n.fmCategoryOther,
    };
  }

  String _protocolLabel(String protocol) {
    return switch (protocol) {
      'lan' => 'HTTP',
      's3' => 'S3',
      'webrtc' => 'WebRTC',
      _ => protocol.toUpperCase(),
    };
  }

  String _md5Display(AppLocalizations l10n) {
    if (_md5Loading) return l10n.fmFileInfoMd5Computing;
    if (!_fileExists) return l10n.fmFileInfoFileMissing;
    if (_md5Failed) return l10n.fmFileInfoMd5Failed;
    return _md5 ?? l10n.fmFileInfoMd5Failed;
  }

  void _copyValue(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    AppToast.show(
      context,
      message: AppLocalizations.of(context).filePreviewCopied,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final file = widget.file;
    final sizeBytes = _sizeBytes ?? file.size;
    final modifiedAt = _modifiedAt ?? file.modified;
    final md5Text = _md5Display(l10n);
    final canCopyMd5 = !_md5Loading && _md5 != null;

    final rows = <_InfoRow>[
      _InfoRow(l10n.fmFileInfoName, file.displayName),
      _InfoRow(
        l10n.fmFileInfoPath,
        file.path,
        copyable: true,
        selectable: true,
      ),
      _InfoRow(l10n.fmFileInfoSize, formatFileSize(sizeBytes)),
      _InfoRow(
        l10n.fmFileInfoMd5,
        md5Text,
        copyable: canCopyMd5,
        selectable: true,
      ),
      _InfoRow(
        l10n.fmFileInfoReceivedAt,
        _formatDateTime(context, file.createdAt),
      ),
      _InfoRow(
        l10n.fmFileInfoModifiedAt,
        _formatDateTime(context, modifiedAt),
      ),
      _InfoRow(
        l10n.fmFileInfoCategory,
        _categoryLabel(l10n, file.category),
      ),
      _InfoRow(l10n.fmFileInfoProtocol, _protocolLabel(file.protocol)),
      _InfoRow(l10n.fmFileInfoMessageId, file.messageId, copyable: true),
      if (file.s3Key != null && file.s3Key!.isNotEmpty)
        _InfoRow(l10n.fmFileInfoS3Key, file.s3Key!, copyable: true),
      if (file.fromDeviceId != null && file.fromDeviceId!.isNotEmpty)
        _InfoRow(
          l10n.fmFileInfoFromDevice,
          file.fromDeviceId!,
          copyable: true,
        ),
    ];

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      titlePadding: AppDialog.titlePadding,
      contentPadding: AppDialog.contentPadding,
      actionsPadding: AppDialog.actionsPadding,
      constraints: AppDialog.contentConstraints,
      title: Row(
        children: [
          Expanded(
            child: Text(
              l10n.fmFileInfoTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 20),
            onPressed: () => Navigator.pop(context),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: colors.border),
              _buildRow(context, rows[i], theme, colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    _InfoRow row,
    ThemeData theme,
    AppThemeColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              row.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: row.selectable
                ? SelectableText(
                    row.value,
                    style: (row.label.contains('MD5')
                            ? withAppFont(
                                theme.textTheme.bodyMedium ?? const TextStyle(),
                                baseWght: context.appBaseWght,
                              )
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                      color: colors.textPrimary,
                    ),
                  )
                : Text(
                    row.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
          ),
          if (row.copyable)
            IconButton(
              icon: Icon(
                LucideIcons.copy,
                size: 16,
                color: colors.textSecondary,
              ),
              onPressed: () => _copyValue(context, row.value),
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool copyable;
  final bool selectable;

  const _InfoRow(
    this.label,
    this.value, {
    this.copyable = false,
    this.selectable = false,
  });
}
