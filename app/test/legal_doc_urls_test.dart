import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/legal/legal_doc_urls.dart';
import 'package:app/preferences/service_region.dart';

void main() {
  group('legal doc URLs', () {
    test('mainland region uses localized legal docs', () {
      expect(
        legalPrivacyUri(
          ServiceRegion.mainlandChina,
          const Locale('zh', 'CN'),
        ).toString(),
        'https://xiachuan.net/zh/docs/privacy',
      );
      expect(
        legalTermsUri(
          ServiceRegion.mainlandChina,
          const Locale('en'),
        ).toString(),
        'https://xiachuan.net/en/docs/terms',
      );
    });

    test('international region uses zh docs for Chinese locale', () {
      expect(
        legalPrivacyUri(
          ServiceRegion.international,
          const Locale('zh', 'CN'),
        ).toString(),
        'https://shrimpsend.com/zh/docs/privacy',
      );
      expect(
        legalTermsUri(
          ServiceRegion.international,
          const Locale('zh', 'CN'),
        ).toString(),
        'https://shrimpsend.com/zh/docs/terms',
      );
    });

    test('international region uses en docs for non-Chinese locale', () {
      expect(
        legalPrivacyUri(
          ServiceRegion.international,
          const Locale('en'),
        ).toString(),
        'https://shrimpsend.com/en/docs/privacy',
      );
      expect(
        legalTermsUri(
          ServiceRegion.international,
          const Locale('fr'),
        ).toString(),
        'https://shrimpsend.com/en/docs/terms',
      );
    });
  });
}
