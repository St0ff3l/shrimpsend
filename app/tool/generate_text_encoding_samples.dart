import 'dart:convert';
import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';

void main() {
  final dir = Directory('samples/text_encoding');
  dir.createSync(recursive: true);

  const utf8Csv = '''校园卡流水,交易时间,交易金额,余额
张三,2021/10/01 06:10:01,-12.50,87.50
李四,2021/10/01 12:30:00,50.00,137.50
Excel导出测试,2021-10-02 08:00:00,0.00,137.50''';
  File('${dir.path}/01_utf8_chinese.csv').writeAsStringSync(utf8Csv);

  final utf8BomBytes = [
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode('中文内容 UTF-8 BOM\n第二行：上善若水'),
  ];
  File('${dir.path}/02_utf8_bom.txt').writeAsBytesSync(utf8BomBytes);

  const gbkCsv = '''校园卡流水,交易时间,交易金额,余额
张三,2021/10/01 06:10:01,-12.50,87.50
李四,2021/10/01 12:30:00,50.00,137.50
姓名,学号,消费地点
王五,20210001,第一食堂''';
  File('${dir.path}/03_gbk_campus_card.csv').writeAsBytesSync(gbk.encode(gbkCsv));

  File('${dir.path}/04_ascii_plain.txt').writeAsStringSync(
    'Hello World\n'
    'Date,Amount,Note\n'
    '2021-10-01,100.00,lunch\n'
    '2021-10-02,50.00,coffee\n',
  );

  const utf16Text = 'UTF-16 LE 中文测试\n上善若水，厚德载物';
  final utf16Bytes = <int>[0xFF, 0xFE];
  for (final unit in utf16Text.codeUnits) {
    utf16Bytes.add(unit & 0xFF);
    utf16Bytes.add(unit >> 8);
  }
  File('${dir.path}/05_utf16le_chinese.txt').writeAsBytesSync(utf16Bytes);

  const gbkReadme = '''【GBK 编码说明文件】
这是 GBK 编码的文本，用于测试自动编码检测。
若显示正常中文而非乱码或 � 符号，说明检测成功。''';
  File('${dir.path}/06_gbk_readme.txt').writeAsBytesSync(gbk.encode(gbkReadme));

  stdout.writeln('Created samples in ${dir.path}:');
  final files = dir
      .listSync()
      .whereType<File>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    stdout.writeln('  ${f.uri.pathSegments.last} (${f.lengthSync()} bytes)');
  }
}
