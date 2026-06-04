import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../preferences/locale_region_store.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../ui/app_ui.dart';

/// First launch: pick display language before login (service region is fixed by build).
class LocaleRegionGateScreen extends StatefulWidget {
  const LocaleRegionGateScreen({super.key, required this.store});

  final LocaleRegionStore store;

  @override
  State<LocaleRegionGateScreen> createState() => _LocaleRegionGateScreenState();
}

class _LocaleRegionGateScreenState extends State<LocaleRegionGateScreen> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.store.notifier.value.locale;
  }

  Future<void> _continue() async {
    await widget.store.setLocale(_locale);
    await widget.store.setLocaleGateCompleted(true);
    Analytics.track(AnalyticsEvents.localeGateCompleted, {
      'locale_tag':
          '${_locale.languageCode}${_locale.countryCode != null ? '_${_locale.countryCode}' : ''}',
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSize.formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.localeRegionGateTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.localeRegionGateSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.fieldLanguage,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<Locale>(
                    segments: [
                      ButtonSegment(
                        value: const Locale('zh', 'CN'),
                        label: Text(l10n.localeNameZhHans),
                      ),
                      ButtonSegment(
                        value: const Locale('en'),
                        label: Text(l10n.localeNameEnglish),
                      ),
                    ],
                    selected: {_locale},
                    onSelectionChanged: (v) {
                      setState(() => _locale = v.first);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _continue,
                    child: Text(l10n.continueAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
