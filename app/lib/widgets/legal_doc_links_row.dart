import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../legal/legal_doc_urls.dart';
import '../preferences/locale_region_store.dart';
import '../ui/app_ui.dart';
import '../utils/toast.dart';

/// Opens privacy policy and terms of service in the external browser.
class LegalDocLinksRow extends StatelessWidget {
  const LegalDocLinksRow({super.key, this.compact = false});

  /// Smaller padding / font when embedded in dense cards.
  final bool compact;

  Future<void> _open(BuildContext context, Uri uri) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      AppToast.show(context, message: l10n.legalCouldNotOpenLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final locale = Localizations.localeOf(context);
    final store = LocaleRegionStoreScope.maybeOf(context);
    if (store == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<LocaleRegionState>(
      valueListenable: store.notifier,
      builder: (context, lr, _) {
        final privacy = legalPrivacyUri(lr.serviceRegion, locale);
        final terms = legalTermsUri(lr.serviceRegion, locale);
        final style = theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        );
        final sepStyle = theme.textTheme.labelLarge?.copyWith(
          color: colors.textTertiary,
        );
        return Padding(
          padding: compact
              ? const EdgeInsets.only(top: AppSpacing.xxs)
              : EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _open(context, privacy),
                child: Text(l10n.legalPrivacyPolicy, style: style),
              ),
              Text('·', style: sepStyle),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _open(context, terms),
                child: Text(l10n.legalTermsOfService, style: style),
              ),
            ],
          ),
        );
      },
    );
  }
}
