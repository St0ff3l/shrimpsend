import 'package:flutter/material.dart';

import '../preferences/service_region.dart';

/// Web origin for docs pages (must match deployed Next.js `/{lang}/docs/{doc}` route).
const String kLegalWebBaseMainland = 'https://xiachuan.net';
const String kLegalWebBaseInternational = 'https://shrimpsend.com';

String _legalLang(Locale locale) {
  final code = locale.languageCode.toLowerCase();
  if (code.startsWith('zh')) return 'zh';
  return 'en';
}

/// Privacy policy URL for the current service cluster and UI language.
Uri legalPrivacyUri(ServiceRegion region, Locale locale) {
  final base = region == ServiceRegion.mainlandChina ? kLegalWebBaseMainland : kLegalWebBaseInternational;
  final lang = _legalLang(locale);
  return Uri.parse('$base/$lang/docs/privacy');
}

/// Terms of service URL for the current service cluster and UI language.
Uri legalTermsUri(ServiceRegion region, Locale locale) {
  final base = region == ServiceRegion.mainlandChina ? kLegalWebBaseMainland : kLegalWebBaseInternational;
  final lang = _legalLang(locale);
  return Uri.parse('$base/$lang/docs/terms');
}
