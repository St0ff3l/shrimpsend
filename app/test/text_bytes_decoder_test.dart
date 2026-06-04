import 'dart:convert';

import 'package:app/utils/text_bytes_decoder.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes plain ASCII', () {
    expect(decodeTextBytes('hello,world'.codeUnits), 'hello,world');
  });

  test('decodes UTF-8 Chinese', () {
    const text = '校园卡流水,2021-10-01';
    expect(decodeTextBytes(utf8.encode(text)), text);
  });

  test('decodes UTF-8 with BOM', () {
    const text = '中文内容';
    final bytes = [..._utf8Bom, ...utf8.encode(text)];
    expect(decodeTextBytes(bytes), text);
  });

  test('decodes GBK Chinese CSV', () {
    const text = '校园卡流水,交易时间,金额\n2021-10-01,06:10:01,100';
    final bytes = gbk.encode(text);
    expect(decodeTextBytes(bytes), text);
  });

  test('prefers GBK over malformed UTF-8 for Chinese CSV', () {
    const text = '姓名,学号,余额\n张三,20210001,50.00';
    final bytes = gbk.encode(text);
    final utf8Attempt = utf8.decode(bytes, allowMalformed: true);
    expect(utf8Attempt.contains('\uFFFD'), isTrue);
    expect(decodeTextBytes(bytes), text);
  });

  test('decodes UTF-16 LE with BOM', () {
    const text = '上善若水';
    final bytes = <int>[0xFF, 0xFE];
    for (final unit in text.codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add(unit >> 8);
    }
    expect(decodeTextBytes(bytes), text);
  });

  test('handles empty file', () {
    expect(decodeTextBytes([]), '');
  });

  test('handles newline only', () {
    expect(decodeTextBytes('\n'.codeUnits), '\n');
  });
}

const _utf8Bom = [0xEF, 0xBB, 0xBF];
