import 'package:flutter/material.dart';

import '../font_size_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../typography.dart';
import '../ui/app_ui.dart';

class FontSettingsScreen extends StatelessWidget {
  const FontSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FontSizeStoreScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsFontsPageTitle),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          store.notifier,
          store.weightNotifier,
        ]),
        builder: (context, _) {
          final theme = Theme.of(context);
          final colors = context.appColors;
          final sizeLevel = store.notifier.value;
          final weightLevel = store.weightNotifier.value;
          final textScale = scaleForFontSizeLevel(sizeLevel);
          final baseWght = store.baseWght;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                elevation: 0,
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.medium,
                  side: BorderSide(color: colors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LevelSlider(
                        label: l10n.settingsFontSizeLabel,
                        index: indexForFontSizeLevel(sizeLevel).toDouble(),
                        labels: kFontSizeLevels
                            .map((level) => _fontSizeLabel(l10n, level))
                            .toList(),
                        onChanged: (value) {
                          final next = fontSizeLevelFromIndex(value.round());
                          store.setLevel(next);
                          Analytics.track(AnalyticsEvents.settingChanged, {
                            'key': 'font_size',
                            'value': encodeFontSizeLevel(next),
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _LevelSlider(
                        label: l10n.settingsFontWeightLabel,
                        index: indexForFontWeightLevel(weightLevel).toDouble(),
                        labels: kFontWeightLevels
                            .map((level) => _fontWeightLabel(l10n, level))
                            .toList(),
                        onChanged: (value) {
                          final next = fontWeightLevelFromIndex(value.round());
                          store.setWeightLevel(next);
                          Analytics.track(AnalyticsEvents.settingChanged, {
                            'key': 'font_weight',
                            'value': encodeFontWeightLevel(next),
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(textScale),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: AppRadius.medium,
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(
                            l10n.settingsFontPreview,
                            style: withAppFont(
                              theme.textTheme.bodyMedium ?? const TextStyle(),
                              baseWght: baseWght,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.settingsFontLicenses,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LevelSlider extends StatelessWidget {
  const _LevelSlider({
    required this.label,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final String label;
  final double index;
  final List<String> labels;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final selectedIndex = index.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: index,
            min: 0,
            max: 4,
            divisions: 4,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: List.generate(labels.length, (i) {
            final selected = i == selectedIndex;
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : colors.textTertiary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

String _fontSizeLabel(AppLocalizations l10n, FontSizeLevel level) {
  switch (level) {
    case FontSizeLevel.smaller:
      return l10n.settingsFontSizeSmaller;
    case FontSizeLevel.small:
      return l10n.settingsFontSizeSmall;
    case FontSizeLevel.standard:
      return l10n.settingsFontSizeStandard;
    case FontSizeLevel.large:
      return l10n.settingsFontSizeLarge;
    case FontSizeLevel.larger:
      return l10n.settingsFontSizeLarger;
  }
}

String _fontWeightLabel(AppLocalizations l10n, FontWeightLevel level) {
  switch (level) {
    case FontWeightLevel.lighter:
      return l10n.settingsFontWeightLighter;
    case FontWeightLevel.light:
      return l10n.settingsFontWeightLight;
    case FontWeightLevel.normal:
      return l10n.settingsFontWeightNormal;
    case FontWeightLevel.medium:
      return l10n.settingsFontWeightMedium;
    case FontWeightLevel.semibold:
      return l10n.settingsFontWeightSemibold;
  }
}
