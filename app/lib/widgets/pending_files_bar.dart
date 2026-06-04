import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/generated/app_localizations.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import 'file_icon_widget.dart';

const int _maxVisibleChipsDesktop = 20;
const double _pendingChipHeight = 32;
const double _pendingManageSheetMaxHeightFactor = 0.8;
const double _pendingChipMaxWidth = 150;

/// Opens the same pending-files list as [PendingFilesBar]「管理」.
void showPendingFilesManageSheet(
  BuildContext context, {
  required List<PlatformFile> files,
  required void Function(PlatformFile file) onRemove,
  required VoidCallback onClearAll,
}) {
  final colors = _pendingBarColors(context);
  final maxHeight =
      MediaQuery.of(context).size.height * _pendingManageSheetMaxHeightFactor;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (_) => _PendingFilesSheet(
      initialFiles: List.of(files),
      onRemove: onRemove,
      onClearAll: onClearAll,
    ),
  );
}

bool get _isMobilePlatform => Platform.isAndroid || Platform.isIOS;

_PendingBarColors _pendingBarColors(BuildContext context) {
  final theme = Theme.of(context);
  final colors = context.appColors;
  return _PendingBarColors(
    surfaceDim: colors.surfaceMuted,
    surface: colors.surface,
    chipBorder: colors.borderStrong,
    onSurface: colors.textPrimary,
    muted: colors.textSecondary,
    accent: theme.colorScheme.primary,
    handle: colors.borderStrong,
    danger: colors.danger,
  );
}

class _PendingBarColors {
  final Color surfaceDim;
  final Color surface;
  final Color chipBorder;
  final Color onSurface;
  final Color muted;
  final Color accent;
  final Color handle;
  final Color danger;
  _PendingBarColors({
    required this.surfaceDim,
    required this.surface,
    required this.chipBorder,
    required this.onSurface,
    required this.muted,
    required this.accent,
    required this.handle,
    required this.danger,
  });
}

class PendingFilesBar extends StatelessWidget {
  final List<PlatformFile> files;
  final VoidCallback onSend;
  final void Function(PlatformFile file) onRemove;
  final VoidCallback onClearAll;

  const PendingFilesBar({
    super.key,
    required this.files,
    required this.onSend,
    required this.onRemove,
    required this.onClearAll,
  });

  void _showManageSheet(BuildContext context) {
    showPendingFilesManageSheet(
      context,
      files: files,
      onRemove: onRemove,
      onClearAll: onClearAll,
    );
  }

  Widget _buildSendButton(BuildContext context, _PendingBarColors colors) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: onSend,
      icon: const Icon(LucideIcons.send, size: 16),
      label: Text(l10n.pendingFilesSend),
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildManageButton(
    BuildContext context,
    _PendingBarColors colors,
    ThemeData theme, {
    required bool showCount,
  }) {
    final l10n = AppLocalizations.of(context);
    final label = showCount
        ? l10n.pendingFilesManageWithCount(files.length)
        : l10n.pendingFilesManage;
    return OutlinedButton(
      onPressed: () => _showManageSheet(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        side: BorderSide(color: colors.chipBorder),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    _PendingBarColors colors,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.pendingFilesSelectedCount(files.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _buildManageButton(context, colors, theme, showCount: false),
        const SizedBox(width: AppSpacing.xs),
        _buildSendButton(context, colors),
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    _PendingBarColors colors,
    ThemeData theme,
  ) {
    final chipCount = files.length.clamp(0, _maxVisibleChipsDesktop);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: _pendingChipHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chipCount,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                return _CompactChip(
                  name: files[index].name,
                  onDelete: () => onRemove(files[index]),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildManageButton(context, colors, theme, showCount: true),
        const SizedBox(width: AppSpacing.xs),
        _buildSendButton(context, colors),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _pendingBarColors(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      color: colors.surfaceDim,
      child: _isMobilePlatform
          ? _buildMobileLayout(context, colors, theme)
          : _buildDesktopLayout(context, colors, theme),
    );
  }
}

class _CompactChip extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;

  const _CompactChip({required this.name, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = _pendingBarColors(context);
    final theme = Theme.of(context);
    return Container(
      height: _pendingChipHeight,
      constraints: const BoxConstraints(maxWidth: _pendingChipMaxWidth),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.pill,
        border: Border.all(color: colors.chipBorder),
      ),
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onDelete,
            child: Icon(LucideIcons.x, size: 14, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _PendingFilesSheet extends StatefulWidget {
  final List<PlatformFile> initialFiles;
  final void Function(PlatformFile file) onRemove;
  final VoidCallback onClearAll;

  const _PendingFilesSheet({
    required this.initialFiles,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  State<_PendingFilesSheet> createState() => _PendingFilesSheetState();
}

class _PendingFilesSheetState extends State<_PendingFilesSheet> {
  late List<PlatformFile> _localFiles;

  @override
  void initState() {
    super.initState();
    _localFiles = List.of(widget.initialFiles);
  }

  void _removeAt(int index) {
    final file = _localFiles[index];
    widget.onRemove(file);
    setState(() {
      _localFiles.removeAt(index);
    });
    if (_localFiles.isEmpty) {
      Navigator.pop(context);
    }
  }

  void _clearAll() {
    widget.onClearAll();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _pendingBarColors(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.handle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  l10n.pendingFilesSelectedCount(_localFiles.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearAll,
                  child: Text(l10n.pendingFilesClearAll,
                      style: TextStyle(color: colors.danger)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.chipBorder),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _localFiles.length,
              itemBuilder: (context, index) {
                final file = _localFiles[index];
                final category = getFileCategory(file.name);
                return ListTile(
                  dense: true,
                  leading: FileIconWidget(category: category, size: 32),
                  title: Text(
                    file.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    formatFileSize(file.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                  trailing: GestureDetector(
                    onTap: () => _removeAt(index),
                    child: Icon(LucideIcons.x, size: 18, color: colors.muted),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
