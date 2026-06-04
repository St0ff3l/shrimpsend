import 'package:flutter_test/flutter_test.dart';

import 'package:app/api/s3.dart';

void main() {
  group('S3StorageMode.parse', () {
    test('parses upper-case string values', () {
      expect(
        S3StorageMode.parse('CUSTOM', fallbackConfigured: false),
        S3StorageMode.custom,
      );
      expect(
        S3StorageMode.parse('HOSTED', fallbackConfigured: false),
        S3StorageMode.hosted,
      );
      expect(
        S3StorageMode.parse('DISABLED', fallbackConfigured: true),
        S3StorageMode.disabled,
      );
    });

    test('is case-insensitive', () {
      expect(
        S3StorageMode.parse('custom', fallbackConfigured: false),
        S3StorageMode.custom,
      );
      expect(
        S3StorageMode.parse('Hosted', fallbackConfigured: false),
        S3StorageMode.hosted,
      );
    });

    test('falls back via legacy `configured` flag when mode is missing', () {
      expect(
        S3StorageMode.parse(null, fallbackConfigured: true),
        S3StorageMode.custom,
        reason: 'legacy backend with configured=true → BYO custom',
      );
      expect(
        S3StorageMode.parse(null, fallbackConfigured: false),
        S3StorageMode.disabled,
      );
    });
  });

  group('S3ConfigDetail.fromJson', () {
    test('CUSTOM: keeps endpoint/bucket fields and configured=true', () {
      final detail = S3ConfigDetail.fromJson({
        'configured': true,
        'mode': 'CUSTOM',
        'hostedAvailable': true,
        'documentationUrl': 'http://localhost:3000/zh/docs/s3/overview',
        'endpoint': 'https://s3.example.com',
        'region': 'us-east-1',
        'bucket': 'b',
        'accessKeyId': 'AK',
        'secretAccessKey': 'SK',
      });
      expect(detail.mode, S3StorageMode.custom);
      expect(detail.configured, isTrue);
      expect(detail.hostedAvailable, isTrue);
      expect(detail.endpoint, 'https://s3.example.com');
      expect(detail.bucket, 'b');
      expect(detail.documentationUrl, 'http://localhost:3000/zh/docs/s3/overview');
    });

    test('HOSTED: configured=true even without endpoint/bucket', () {
      final detail = S3ConfigDetail.fromJson({
        'configured': true,
        'mode': 'HOSTED',
        'hostedAvailable': true,
      });
      expect(detail.mode, S3StorageMode.hosted);
      expect(detail.configured, isTrue,
          reason: 'HOSTED users should be considered S3-enabled');
      expect(detail.endpoint, isNull);
      expect(detail.bucket, isNull);
    });

    test('DISABLED: configured=false', () {
      final detail = S3ConfigDetail.fromJson({
        'configured': false,
        'mode': 'DISABLED',
        'hostedAvailable': false,
      });
      expect(detail.mode, S3StorageMode.disabled);
      expect(detail.configured, isFalse);
      expect(detail.hostedAvailable, isFalse);
    });

    test('legacy backend without `mode` falls back to configured flag', () {
      final byo = S3ConfigDetail.fromJson({
        'configured': true,
        'endpoint': 'https://s3.example.com',
        'bucket': 'b',
      });
      expect(byo.mode, S3StorageMode.custom);
      expect(byo.configured, isTrue);

      final none = S3ConfigDetail.fromJson({'configured': false});
      expect(none.mode, S3StorageMode.disabled);
      expect(none.configured, isFalse);
    });

    test('disabled() factory returns DISABLED with all flags off', () {
      final d = S3ConfigDetail.disabled();
      expect(d.mode, S3StorageMode.disabled);
      expect(d.configured, isFalse);
      expect(d.hostedAvailable, isFalse);
    });
  });
}
