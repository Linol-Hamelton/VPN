import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/utils/link_parsers.dart';

void main() {
  group('LinkParser.parseFromText', () {
    test('extracts direct url from mixed text', () {
      const input = 'Subscription from telegram: https://example.com/sub?token=abc';
      final parsed = LinkParser.parseFromText(input);

      expect(parsed, isNotNull);
      expect(parsed!.url, 'https://example.com/sub?token=abc');
    });

    test('decodes encoded hiddify import url', () {
      const input = 'hiddify://import/https%3A%2F%2Fexample.com%2Fsub%3Ftoken%3Dabc';
      final parsed = LinkParser.parseFromText(input);

      expect(parsed, isNotNull);
      expect(parsed!.url, 'https://example.com/sub?token=abc');
    });

    test('extracts nested import link from telegram wrapper', () {
      const input =
          'https://t.me/some_channel/123?single&url=hiddify%3A%2F%2Fimport%2Fhttps%253A%252F%252Fexample.com%252Fsub%253Ftoken%253Dabc';
      final parsed = LinkParser.parseFromText(input);

      expect(parsed, isNotNull);
      expect(parsed!.url, 'https://example.com/sub?token=abc');
    });

    test('prioritizes non-telegram direct links over telegram wrappers', () {
      const input = 'https://t.me/some_channel/123 and backup https://example.com/sub';
      final candidates = LinkParser.parseCandidatesFromText(input);

      expect(candidates, isNotEmpty);
      expect(candidates.first.url, 'https://example.com/sub');
    });
  });
}
