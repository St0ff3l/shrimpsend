import 'package:app/utils/link_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkTextParser.parse', () {
    test('returns null when text has no links', () {
      expect(LinkTextParser.parse('hello world'), isNull);
      expect(LinkTextParser.parse(''), isNull);
    });

    test('parses a single http link', () {
      final segments = LinkTextParser.parse('see https://example.com now')!;
      expect(segments.length, 3);
      expect(segments[0].text, 'see ');
      expect(segments[0].url, isNull);
      expect(segments[1].text, 'https://example.com');
      expect(segments[1].url, 'https://example.com');
      expect(segments[2].text, ' now');
    });

    test('parses multiple links', () {
      final segments = LinkTextParser.parse(
        'a https://a.com b https://b.com/path c',
      )!;
      expect(segments.length, 5);
      expect(segments[1].url, 'https://a.com');
      expect(segments[3].url, 'https://b.com/path');
    });

    test('strips trailing punctuation from links', () {
      final segments = LinkTextParser.parse('访问 https://a.com.')!;
      expect(segments[1].url, 'https://a.com');
      expect(segments[2].text, '.');
    });

    test('parses www links', () {
      final segments = LinkTextParser.parse('go www.example.com/path')!;
      expect(segments[1].url, 'www.example.com/path');
    });

    test('handles Chinese text around links', () {
      final segments = LinkTextParser.parse('请看 https://foo.bar/x 和 www.baz.com')!;
      expect(segments.first.text, '请看 ');
      expect(segments[1].url, 'https://foo.bar/x');
      expect(segments[2].text, ' 和 ');
      expect(segments[3].url, 'www.baz.com');
    });

    test('stops before trailing Chinese punctuation and text', () {
      const input =
          '我昨天看了这篇文章，觉得不错：https://developer.mozilla.org/zh-CN/docs/Web/JavaScript，推荐你也看看';
      final segments = LinkTextParser.parse(input)!;
      expect(segments[1].url, 'https://developer.mozilla.org/zh-CN/docs/Web/JavaScript');
      expect(segments[2].text, '，推荐你也看看');
    });
  });

  group('LinkTextParser.toLaunchUri', () {
    test('accepts http and https', () {
      expect(
        LinkTextParser.toLaunchUri('https://example.com')?.toString(),
        'https://example.com',
      );
      expect(
        LinkTextParser.toLaunchUri('http://example.com/path?q=1')?.toString(),
        'http://example.com/path?q=1',
      );
    });

    test('adds https for www links', () {
      expect(
        LinkTextParser.toLaunchUri('www.example.com/path')?.toString(),
        'https://www.example.com/path',
      );
    });

    test('returns null for invalid input', () {
      expect(LinkTextParser.toLaunchUri(''), isNull);
      expect(LinkTextParser.toLaunchUri('ftp://example.com'), isNull);
      expect(LinkTextParser.toLaunchUri('not a url'), isNull);
    });
  });
}
