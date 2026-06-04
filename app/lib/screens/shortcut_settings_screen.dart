import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../shortcut_preferences.dart';
import '../ui/app_ui.dart';

class ShortcutSettingsScreen extends StatefulWidget {
  const ShortcutSettingsScreen({super.key});

  @override
  State<ShortcutSettingsScreen> createState() => _ShortcutSettingsScreenState();
}

class _ShortcutSettingsScreenState extends State<ShortcutSettingsScreen> {
  SendShortcutMode _sendShortcutMode = sendShortcutModeNotifier.value;

  @override
  void initState() {
    super.initState();
    _sendShortcutMode = sendShortcutModeNotifier.value;
    sendShortcutModeNotifier.addListener(_onModeChanged);
    getSendShortcutMode().then((mode) {
      if (!mounted) return;
      setState(() => _sendShortcutMode = mode);
    });
  }

  @override
  void dispose() {
    sendShortcutModeNotifier.removeListener(_onModeChanged);
    super.dispose();
  }

  void _onModeChanged() {
    if (!mounted) return;
    setState(() => _sendShortcutMode = sendShortcutModeNotifier.value);
  }

  void _applyMode(SendShortcutMode mode) {
    setState(() => _sendShortcutMode = mode);
    setSendShortcutMode(mode);
    Analytics.track(AnalyticsEvents.settingChanged, {
      'key': 'send_shortcut',
      'value': encodeSendShortcutModeForAnalytics(mode),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsShortcutsPageTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortcutsSendTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l10n.shortcutsSendDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SendShortcutSegment(
                  mode: _sendShortcutMode,
                  onChanged: _applyMode,
                ),
                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.shortcutsSendButtonHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final colors = context.appColors;
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class _SendShortcutSegment extends StatelessWidget {
  const _SendShortcutSegment({
    required this.mode,
    required this.onChanged,
  });

  final SendShortcutMode mode;
  final ValueChanged<SendShortcutMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final modifierLabel = Platform.isMacOS
        ? l10n.shortcutsSendModifierMac
        : l10n.shortcutsSendModifier;
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(context, l10n.shortcutsSendEnter, SendShortcutMode.enter, theme, colors),
        _chip(context, modifierLabel, SendShortcutMode.modifierEnter, theme, colors),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    SendShortcutMode value,
    ThemeData theme,
    AppThemeColors colors,
  ) {
    final selected = mode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      showCheckmark: false,
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: selected ? theme.colorScheme.onPrimary : colors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
