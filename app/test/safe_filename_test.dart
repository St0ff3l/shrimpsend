import 'package:app/utils/safe_filename.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves CJK and common punctuation', () {
    expect(sanitizeFileNameForLocalStorage('季度报告.pdf'), '季度报告.pdf');
    expect(sanitizeFileNameForLocalStorage('a_b_c.pdf'), 'a_b_c.pdf');
    expect(sanitizeFileNameForLocalStorage('file (1).txt'), 'file (1).txt');
  });

  test('strips path segments', () {
    expect(sanitizeFileNameForLocalStorage(r'evil\..\foo\bar.txt'), 'bar.txt');
    expect(sanitizeFileNameForLocalStorage('sub/dir/name.pdf'), 'name.pdf');
  });

  test('replaces forbidden characters', () {
    expect(sanitizeFileNameForLocalStorage('a:b.pdf'), 'a_b.pdf');
    expect(sanitizeFileNameForLocalStorage('a|b'), 'a_b');
  });

  test('empty or dot segments fall back', () {
    expect(sanitizeFileNameForLocalStorage('..'), 'file');
    expect(sanitizeFileNameForLocalStorage('.'), 'file');
  });
}
