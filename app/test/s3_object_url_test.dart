import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/s3_object_url.dart';

void main() {
  group('buildS3ObjectUri', () {
    test('path-style encodes bucket and key segments', () {
      final uri = buildS3ObjectUri(
        endpoint: 'https://minio.example.com',
        bucket: 'my-bucket',
        key: 'uploads/a b.txt',
        pathStyleAccessEnabled: true,
      );
      expect(uri.toString(),
          'https://minio.example.com/my-bucket/uploads/a%20b.txt');
    });

    test('virtual-hosted inserts bucket subdomain', () {
      final uri = buildS3ObjectUri(
        endpoint: 'https://s3.us-east-1.amazonaws.com',
        bucket: 'my-bucket',
        key: 'uploads/file.txt',
        pathStyleAccessEnabled: false,
      );
      expect(uri.host, 'my-bucket.s3.us-east-1.amazonaws.com');
      expect(uri.path, '/uploads/file.txt');
    });

    test('virtual-hosted does not duplicate bucket prefix', () {
      final uri = buildS3ObjectUri(
        endpoint: 'https://my-bucket.s3.us-east-1.amazonaws.com',
        bucket: 'my-bucket',
        key: 'uploads/file.txt',
        pathStyleAccessEnabled: false,
      );
      expect(uri.host, 'my-bucket.s3.us-east-1.amazonaws.com');
    });
  });
}
