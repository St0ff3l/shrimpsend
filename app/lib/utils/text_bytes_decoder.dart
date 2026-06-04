import 'dart:convert';
import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';

const _utf8Bom = [0xEF, 0xBB, 0xBF];
const _utf16LeBom = [0xFF, 0xFE];
const _utf16BeBom = [0xFE, 0xFF];

const _malformedGbk = GbkCodec(allowMalformed: true);

/// Reads up to [maxBytes] from [path] for text preview / copy.
Future<List<int>> readTextFileBytes(
  String path, {
  int maxBytes = 2 * 1024 * 1024,
}) async {
  final file = File(path);
  final stat = await file.stat();
  if (stat.size > maxBytes) {
    return file
        .openRead(0, maxBytes)
        .fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
  }
  return file.readAsBytes();
}

/// Decodes raw file bytes using BOM hints and UTF-8 / GBK heuristics.
String decodeTextBytes(List<int> bytes) {
  if (bytes.isEmpty) return '';

  if (_hasPrefix(bytes, _utf8Bom)) {
    return utf8.decode(bytes.sublist(_utf8Bom.length), allowMalformed: true);
  }
  if (_hasPrefix(bytes, _utf16LeBom)) {
    return _decodeUtf16Le(bytes);
  }
  if (_hasPrefix(bytes, _utf16BeBom)) {
    return _decodeUtf16Be(bytes);
  }

  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    // Fall through to heuristic comparison.
  }

  final utf8Text = utf8.decode(bytes, allowMalformed: true);
  final gbkText = _malformedGbk.decode(bytes);
  final utf8Score = _scoreDecodedText(utf8Text);
  final gbkScore = _scoreDecodedText(gbkText);
  return gbkScore > utf8Score ? gbkText : utf8Text;
}

String _decodeUtf16Le(List<int> bytes) {
  final codeUnits = <int>[];
  for (var i = _utf16LeBom.length; i + 1 < bytes.length; i += 2) {
    codeUnits.add(bytes[i] | (bytes[i + 1] << 8));
  }
  return String.fromCharCodes(codeUnits);
}

String _decodeUtf16Be(List<int> bytes) {
  final codeUnits = <int>[];
  for (var i = _utf16BeBom.length; i + 1 < bytes.length; i += 2) {
    codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(codeUnits);
}

bool _hasPrefix(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

int _scoreDecodedText(String text) {
  var score = 0;
  for (final rune in text.runes) {
    if (rune == 0xFFFD) {
      score -= 100;
    } else if (rune >= 0x4E00 && rune <= 0x9FFF) {
      score += 10;
    } else if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) {
      score -= 50;
    } else if (rune >= 0x20 && rune <= 0x7E) {
      score += 1;
    }
  }
  return score;
}
