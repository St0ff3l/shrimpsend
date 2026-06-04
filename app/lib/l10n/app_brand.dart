import 'package:flutter/widgets.dart';

import '../preferences/service_region.dart';
import 'generated/app_localizations.dart';

/// UI brand line (虾传 vs ShrimpSend) from region, localized.
String brandProductName(AppLocalizations l10n, ServiceRegion region) {
  return region == ServiceRegion.mainlandChina
      ? l10n.brandNameMainlandChina
      : l10n.brandNameInternational;
}

/// Same as [brandProductName] using the ambient locale from [context].
String brandDisplayName(BuildContext context, ServiceRegion region) {
  return brandProductName(AppLocalizations.of(context), region);
}
