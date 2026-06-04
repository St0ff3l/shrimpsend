import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/app_update_service.dart';
import '../ui/app_ui.dart';

class VersionHistoryScreen extends StatefulWidget {
  const VersionHistoryScreen({super.key});

  @override
  State<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends State<VersionHistoryScreen> {
  List<UpdateInfo> _versions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await fetchVersionHistory();
    if (mounted) {
      setState(() {
        _versions = list;
        _loading = false;
      });
    }
  }

  static String _formatReleasedAt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.versionHistoryTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _versions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.history, size: 48, color: colors.textTertiary),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.versionHistoryEmpty,
                        style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _versions.length,
                  itemBuilder: (context, index) {
                    final v = _versions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'v${v.version} (${v.buildNumber})',
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                if (v.releasedAt != null && v.releasedAt!.isNotEmpty)
                                  Text(
                                    _formatReleasedAt(v.releasedAt),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                            if (v.releaseNotes.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                v.releaseNotes,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
