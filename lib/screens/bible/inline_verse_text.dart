import 'package:flutter/material.dart';

import '../../models/chapter_response.dart';

const String inlineVerseGap = '  ';
typedef VerseInlineSpanBuilder = InlineSpan Function(
  Verse verse,
  String normalizedText,
);

String normalizeInlineVerseText(Verse verse) {
  final trimmedText = verse.text.trim();
  if (trimmedText.isEmpty) {
    return '';
  }

  final duplicatePrefixPattern = RegExp('^${verse.number}\\s+');
  return trimmedText.replaceFirst(duplicatePrefixPattern, '').trim();
}

List<InlineSpan> buildInlineVerseSpans({
  required List<Verse> verses,
  required VerseInlineSpanBuilder spanBuilder,
  InlineSpan? separator,
}) {
  final spans = <InlineSpan>[];

  for (final verse in verses) {
    final normalizedText = normalizeInlineVerseText(verse);
    if (normalizedText.isEmpty) {
      continue;
    }

    if (spans.isNotEmpty) {
      spans.add(separator ?? const TextSpan(text: inlineVerseGap));
    }

    spans.add(spanBuilder(verse, normalizedText));
  }

  return spans;
}

TextSpan buildInlineVerseTextSpan({
  required List<Verse> verses,
  required TextStyle bodyStyle,
  required TextStyle numberStyle,
}) {
  return TextSpan(
    children: buildInlineVerseSpans(
      verses: verses,
      separator: TextSpan(text: inlineVerseGap, style: bodyStyle),
      spanBuilder: (Verse verse, String normalizedText) {
        return TextSpan(
          children: <InlineSpan>[
            TextSpan(text: '${verse.number} ', style: numberStyle),
            TextSpan(text: normalizedText, style: bodyStyle),
          ],
        );
      },
    ),
  );
}
