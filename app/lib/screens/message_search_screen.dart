import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/messages.dart' as api;
import '../api/messages.dart' show MessageEnvelope;
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../services/chat_message_dao.dart';
import '../ui/app_ui.dart';
import '../widgets/app_confirm_dialog.dart';
import '../utils/helpers.dart';
import '../utils/toast.dart';

class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({super.key});

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<MessageEnvelope> _results = [];
  final Set<int> _expandedIndices = {};
  bool _loading = false;
  bool _hasMore = true;
  String _query = '';
  int? _hoveredIndex;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = value.trim();
      if (q == _query) return;
      _query = q;
      _results = [];
      _expandedIndices.clear();
      _hasMore = true;
      if (q.isEmpty) {
        setState(() {});
        return;
      }
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    if (_loading || _query.isEmpty) return;
    setState(() => _loading = true);
    final beforePage = _results.isNotEmpty ? _results.last.ts : null;
    try {
      final list = await ChatMessageDao.instance.searchMessages(
        userIds: await _localSearchUserIds(),
        query: _query,
        limit: 50,
        beforeTs: beforePage,
      );
      if (!mounted) return;
      final visible = list
          .map(
            (m) => MessageEnvelope(
              type: m.type,
              payload: m.payload,
              fromDeviceId: m.fromDeviceId,
              ts: m.ts,
              localId: m.id,
              threadKey: m.threadKey,
            ),
          )
          .toList();
      setState(() {
        _results.addAll(visible);
        _hasMore = list.length >= 50;
        _loading = false;
      });
      Analytics.track(AnalyticsEvents.messageSearch, {
        'query_len': _query.length,
        'results_count': visible.length,
        'page': beforePage == null ? 'first' : 'next',
        'result': 'success',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      Analytics.track(AnalyticsEvents.messageSearch, {
        'query_len': _query.length,
        'results_count': 0,
        'page': beforePage == null ? 'first' : 'next',
        'result': 'fail',
      });
      AppToast.show(
        context,
        message: AppLocalizations.of(context).msgSearchFailed('$e'),
      );
    }
  }

  Future<List<String>> _localSearchUserIds() async {
    final ids = <String>[];
    final userId = await getStoredUserId();
    if (userId != null && userId.isNotEmpty) {
      ids.add(userId);
    }
    final offlineId = await getOrCreateOfflineUserId();
    if (!ids.contains(offlineId)) {
      ids.add(offlineId);
    }
    return ids;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_loading) {
      _performSearch();
    }
  }

  String _extractDisplayText(MessageEnvelope msg, AppLocalizations l10n) {
    if (msg.type == 'text') {
      final payload = msg.payload is Map ? msg.payload as Map : null;
      return payload?['text']?.toString() ?? '';
    }
    if (msg.type == 'file') {
      final payload = msg.payload is Map ? msg.payload as Map : null;
      final fileName =
          payload?['fileName']?.toString() ?? l10n.msgSearchFileFallback;
      final size = payload?['size'] is int ? payload!['size'] as int : null;
      return '📎 $fileName${size != null ? ' (${formatSize(size)})' : ''}';
    }
    return l10n.msgSearchUnknownMessage;
  }

  String _formatTime(int ts, AppLocalizations l10n) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);

    if (msgDay == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (msgDay == today.subtract(const Duration(days: 1))) {
      final clock =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return l10n.msgSearchYesterdayTime(clock);
    }
    if (dt.year == now.year) {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  String _shortDeviceId(String deviceId, AppLocalizations l10n) {
    if (deviceId == 'system') return l10n.msgSearchDeviceSystem;
    return deviceId;
  }

  // ── Mobile: long-press bottom sheet ──

  void _showMessageActions(MessageEnvelope msg, int index) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final isText = msg.type == 'text';
    final displayText = _extractDisplayText(msg, l10n);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      builder: (ctx) => SafeArea(
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
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isText)
              ListTile(
                leading: const Icon(LucideIcons.copy),
                title: Text(l10n.chatMenuCopyText),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: displayText));
                  AppToast.show(context, message: l10n.msgSearchCopied);
                },
              ),
            if (isText)
              ListTile(
                leading: const Icon(LucideIcons.textCursorInput),
                title: Text(l10n.chatMenuSelectText),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSelectableTextDialog(displayText);
                },
              ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: colors.danger),
              title: Text(l10n.fmDeleteConfirm,
                  style: TextStyle(color: colors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteMessage(msg, index);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  void _showSelectableTextDialog(String text) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        titlePadding: AppDialog.titlePadding,
        contentPadding: AppDialog.contentPadding,
        constraints: AppDialog.contentConstraints,
        title: Row(
          children: [
            Expanded(
              child: Text(l10n.msgSearchSelectTextTitle,
                  style: theme.textTheme.titleMedium),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 20),
              onPressed: () => Navigator.pop(ctx),
              style: IconButton.styleFrom(
                foregroundColor: colors.textTertiary,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        content: SelectableText(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ── Desktop: copy action via button ──

  void _copyText(MessageEnvelope msg) {
    final l10n = AppLocalizations.of(context);
    final displayText = _extractDisplayText(msg, l10n);
    Clipboard.setData(ClipboardData(text: displayText));
    AppToast.show(context, message: l10n.msgSearchCopied);
  }

  Future<void> _confirmDeleteMessage(MessageEnvelope msg, int index) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.msgSearchDeleteTitle,
      content: l10n.msgSearchDeleteBody,
      confirmLabel: l10n.fmDeleteConfirm,
      isDanger: true,
      icon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;

    final serverId = msg.id;
    setState(() {
      _results.removeAt(index);
      _expandedIndices.remove(index);
    });

    if (serverId != null) {
      try {
        await api.deleteMessage(serverId);
      } catch (_) {}
    }
    final localId = msg.localId;
    if (localId != null && localId.isNotEmpty) {
      try {
        await ChatMessageDao.instance.deleteById(localId);
      } catch (_) {}
    }
  }

  List<InlineSpan> _buildHighlightedText(
    String text,
    String query,
    TextStyle baseStyle,
    Color highlightColor,
  ) {
    if (query.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: baseStyle.copyWith(
          color: highlightColor,
          fontWeight: FontWeight.w600,
        ),
      ));
      start = idx + query.length;
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: l10n.msgSearchHint,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.small,
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.small,
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.small,
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.4,
                ),
              ),
              filled: true,
              fillColor: colors.surface,
            ),
          ),
        ),
      ),
      body: _buildBody(colors, theme, l10n),
    );
  }

  Widget _buildBody(AppThemeColors colors, ThemeData theme, AppLocalizations l10n) {
    if (_query.isEmpty) {
      return Center(
        child: Text(
          l10n.msgSearchEmptyHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textTertiary,
          ),
        ),
      );
    }

    if (_results.isEmpty && !_loading) {
      return Center(
        child: Text(
          l10n.msgSearchNoResults,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textTertiary,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      itemCount: _results.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final msg = _results[index];
        final isExpanded = _expandedIndices.contains(index);
        final displayText = _extractDisplayText(msg, l10n);
        final timeStr = _formatTime(msg.ts, l10n);
        final deviceStr = _shortDeviceId(msg.fromDeviceId, l10n);
        final baseTextStyle =
            theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
        final isText = msg.type == 'text';

        if (_isMobile) {
          return _buildMobileItem(
            index, msg, isExpanded, displayText, timeStr, deviceStr,
            baseTextStyle, colors, theme,
          );
        }
        return _buildDesktopItem(
          index, msg, isExpanded, isText, displayText, timeStr, deviceStr,
          baseTextStyle, colors, theme,
        );
      },
    );
  }

  // ── Mobile item: tap to expand, long-press for menu ──

  Widget _buildMobileItem(
    int index,
    MessageEnvelope msg,
    bool isExpanded,
    String displayText,
    String timeStr,
    String deviceStr,
    TextStyle baseTextStyle,
    AppThemeColors colors,
    ThemeData theme,
  ) {
    final textWidget = isExpanded
        ? RichText(
            text: TextSpan(
              children: _buildHighlightedText(
                displayText,
                _query,
                baseTextStyle.copyWith(color: colors.textPrimary),
                theme.colorScheme.primary,
              ),
            ),
          )
        : RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: _buildHighlightedText(
                displayText,
                _query,
                baseTextStyle.copyWith(color: colors.textPrimary),
                theme.colorScheme.primary,
              ),
            ),
          );

    if (!isExpanded) {
      return GestureDetector(
        onTap: () => _toggleExpand(index, false),
        onLongPress: () => _showMessageActions(msg, index),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.small,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderRow(msg, deviceStr, timeStr, colors, theme),
              const SizedBox(height: AppSpacing.xxs),
              textWidget,
            ],
          ),
        ),
      );
    }

    final collapseBtn = GestureDetector(
      onTap: () => _toggleExpand(index, true),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Icon(
          LucideIcons.chevronUp,
          size: 16,
          color: colors.textTertiary,
        ),
      ),
    );

    return GestureDetector(
      onLongPress: () => _showMessageActions(msg, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.small,
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(
              msg,
              deviceStr,
              timeStr,
              colors,
              theme,
              trailing: collapseBtn,
            ),
            const SizedBox(height: AppSpacing.xxs),
            textWidget,
          ],
        ),
      ),
    );
  }

  // ── Desktop item: tap to expand, hover for action buttons, SelectionArea ──

  Widget _buildDesktopItem(
    int index,
    MessageEnvelope msg,
    bool isExpanded,
    bool isText,
    String displayText,
    String timeStr,
    String deviceStr,
    TextStyle baseTextStyle,
    AppThemeColors colors,
    ThemeData theme,
  ) {
    final isHovered = _hoveredIndex == index;

    final textWidget = isExpanded
        ? RichText(
            text: TextSpan(
              children: _buildHighlightedText(
                displayText,
                _query,
                baseTextStyle.copyWith(color: colors.textPrimary),
                theme.colorScheme.primary,
              ),
            ),
          )
        : RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: _buildHighlightedText(
                displayText,
                _query,
                baseTextStyle.copyWith(color: colors.textPrimary),
                theme.colorScheme.primary,
              ),
            ),
          );

    if (!isExpanded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) {
            if (_hoveredIndex == index) setState(() => _hoveredIndex = null);
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleExpand(index, false),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.small,
                border: Border.all(color: colors.border),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow(msg, deviceStr, timeStr, colors, theme),
                      const SizedBox(height: AppSpacing.xxs),
                      textWidget,
                    ],
                  ),
                  if (isHovered)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _buildHoverActions(msg, index, isText, colors),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final collapseBtn = GestureDetector(
      onTap: () => _toggleExpand(index, true),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Icon(
            LucideIcons.chevronUp,
            size: 16,
            color: colors.textTertiary,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredIndex = index),
        onExit: (_) {
          if (_hoveredIndex == index) setState(() => _hoveredIndex = null);
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.small,
            border: Border.all(color: colors.border),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(
                    msg,
                    deviceStr,
                    timeStr,
                    colors,
                    theme,
                    trailing: collapseBtn,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  SelectableText.rich(
                    TextSpan(
                      style: baseTextStyle.copyWith(color: colors.textPrimary),
                      children: _buildHighlightedText(
                        displayText,
                        _query,
                        baseTextStyle.copyWith(color: colors.textPrimary),
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (isHovered)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildHoverActions(msg, index, isText, colors),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    MessageEnvelope msg,
    String deviceStr,
    String timeStr,
    AppThemeColors colors,
    ThemeData theme, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(
          msg.type == 'file' ? LucideIcons.file : LucideIcons.messageSquare,
          size: 14,
          color: colors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          deviceStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textTertiary,
            fontSize: 11,
          ),
        ),
        const Spacer(),
        Text(
          timeStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textTertiary,
            fontSize: 11,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.xxs),
          trailing,
        ],
      ],
    );
  }

  Widget _buildHoverActions(
    MessageEnvelope msg,
    int index,
    bool isText,
    AppThemeColors colors,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isText)
            _hoverIconButton(
              LucideIcons.copy,
              colors.textSecondary,
              () => _copyText(msg),
            ),
          _hoverIconButton(
            LucideIcons.trash2,
            colors.danger,
            () => _confirmDeleteMessage(msg, index),
          ),
        ],
      ),
    );
  }

  Widget _hoverIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _toggleExpand(int index, bool isExpanded) {
    setState(() {
      if (isExpanded) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
      }
    });
  }
}
