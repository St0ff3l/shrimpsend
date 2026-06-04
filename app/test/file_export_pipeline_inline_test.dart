import 'package:app/services/file_export_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileExportPipeline inline API', () {
    test('exportNow returns false for empty messageId', () async {
      final ok = await FileExportPipeline.instance.exportNow('');
      expect(ok, isFalse);
    });

    test('singleton exposes exportNow', () {
      expect(FileExportPipeline.instance.exportNow, isA<Future<bool> Function(String)>());
    });
  });
}
