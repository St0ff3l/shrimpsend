import 'package:app/services/received_file_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceivedFileDao.cacheTabWhereClause', () {
    test('includes pending exports and rows with cache_path', () {
      expect(
        ReceivedFileDao.cacheTabWhereClause,
        contains("export_status IN ('pending', 'exporting', 'failed')"),
      );
      expect(
        ReceivedFileDao.cacheTabWhereClause,
        contains("cache_path IS NOT NULL AND cache_path != ''"),
      );
    });
  });
}
