import 'package:app/lan/transfer_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('makeFileId', () {
    test('same name and size differ when localId differs', () {
      final a = makeFileId('photo.jpg', 1024, localId: 'uuid-a');
      final b = makeFileId('photo.jpg', 1024, localId: 'uuid-b');
      expect(a, isNot(b));
    });

    test('legacy id stable without localId', () {
      final first = makeFileId('doc.pdf', 500);
      final second = makeFileId('doc.pdf', 500);
      expect(first, second);
    });

    test('localId changes id vs legacy', () {
      final legacy = makeFileId('doc.pdf', 500);
      final withId = makeFileId('doc.pdf', 500, localId: 'transfer-1');
      expect(legacy, isNot(withId));
    });
  });
}
