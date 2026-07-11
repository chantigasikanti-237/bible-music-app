import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_app/models/chapter_response.dart';
import 'package:bible_app/screens/bible/inline_verse_text.dart';

void main() {
  group('inline verse text', () {
    test('normalizes duplicated leading verse numbers', () {
      expect(
        normalizeInlineVerseText(
          const Verse(number: 3, text: '3 I want you to swear'),
        ),
        'I want you to swear',
      );
    });

    test('keeps verse text that does not duplicate its own number', () {
      expect(
        normalizeInlineVerseText(
          const Verse(number: 2, text: '20 years later he returned'),
        ),
        '20 years later he returned',
      );
    });

    test('builds one flowing inline passage from verses', () {
      final passage = buildInlineVerseTextSpan(
        verses: const <Verse>[
          Verse(number: 1, text: '1 Abraham was now very old'),
          Verse(number: 2, text: 'He said to the senior servant'),
        ],
        bodyStyle: const TextStyle(fontSize: 20),
        numberStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );

      expect(
        passage.toPlainText(),
        '1 Abraham was now very old  2 He said to the senior servant',
      );
    });
  });
}
