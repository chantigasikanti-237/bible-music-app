class Verse {
  const Verse({
    required this.number,
    required this.text,
  });

  final int number;
  final String text;

  factory Verse.fromJson(
    Map<String, dynamic> json, {
    required int fallbackNumber,
  }) {
    final number = _asInt(json['number']) ??
        _asInt(json['verseNumber']) ??
        _asInt(json['verse']) ??
        fallbackNumber;
    final text = _cleanText(
      _nonEmptyString(json['text']) ??
          _nonEmptyString(json['content']) ??
          _nonEmptyString(json['verseText']) ??
          '',
    );

    return Verse(number: number, text: text);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'number': number,
      'text': text,
    };
  }
}

class Book {
  Book({
    required this.name,
    required Map<int, List<Verse>> chapters,
  }) : chapters = Map<int, List<Verse>>.unmodifiable(
          chapters.map(
            (int chapterNumber, List<Verse> verses) => MapEntry(
              chapterNumber,
              List<Verse>.unmodifiable(verses),
            ),
          ),
        );

  final String name;
  final Map<int, List<Verse>> chapters;

  List<int> get chapterNumbers {
    final numbers = chapters.keys.toList(growable: false);
    numbers.sort();
    return numbers;
  }

  factory Book.fromBibleEntry(String name, dynamic rawChapters) {
    final normalizedName = name.trim();
    final chapters = <int, List<Verse>>{};
    final chaptersMap = _asMap(rawChapters);
    if (chaptersMap != null) {
      chaptersMap.forEach((String chapterKey, dynamic chapterVerses) {
        final chapterNumber = int.tryParse(chapterKey.trim());
        if (chapterNumber == null) {
          return;
        }
        chapters[chapterNumber] = _parseVerseList(chapterVerses);
      });
    }

    return Book(name: normalizedName, chapters: chapters);
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    final name = _nonEmptyString(json['name']) ?? '';
    final chapters = <int, List<Verse>>{};
    final rawChapters = _asMap(json['chapters']);

    if (rawChapters != null) {
      rawChapters.forEach((String chapterKey, dynamic chapterVerses) {
        final chapterNumber = int.tryParse(chapterKey.trim());
        if (chapterNumber == null) {
          return;
        }
        chapters[chapterNumber] = _parseVerseList(chapterVerses);
      });
    }

    return Book(name: name, chapters: chapters);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'chapters': chapters.map<String, dynamic>(
        (int chapter, List<Verse> verses) => MapEntry<String, dynamic>(
          chapter.toString(),
          verses.map((Verse verse) => verse.toJson()).toList(growable: false),
        ),
      ),
    };
  }
}

class ChapterResponse {
  ChapterResponse({
    required this.success,
    required this.bibleId,
    required this.passageId,
    required this.content,
    this.audioUrl,
    required List<Verse> verses,
  }) : verses = List<Verse>.unmodifiable(verses);

  final bool success;
  final int bibleId;
  final String passageId;
  final String content;
  final String? audioUrl;
  final List<Verse> verses;

  factory ChapterResponse.fromJson(
    Map<String, dynamic> json, {
    required int fallbackBibleId,
    required String fallbackPassageId,
  }) {
    final payload = _asMap(json['data']) ?? json;
    final content = _cleanText(payload['content']?.toString() ?? '');

    return ChapterResponse(
      success: json['success'] != false,
      bibleId: _asInt(payload['bibleId']) ??
          _asInt(json['bibleId']) ??
          fallbackBibleId,
      passageId: _nonEmptyString(payload['passageId']) ??
          _nonEmptyString(json['passageId']) ??
          fallbackPassageId,
      content: content,
      audioUrl: _nonEmptyString(payload['audioUrl']) ??
          _nonEmptyString(payload['audio_url']) ??
          _nonEmptyString(json['audioUrl']) ??
          _nonEmptyString(json['audio_url']),
      verses: _extractVerses(payload, content),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'success': success,
      'bibleId': bibleId,
      'passageId': passageId,
      'content': content,
      'audioUrl': audioUrl,
      'verses': verses.map((Verse verse) => verse.toJson()).toList(),
    };
  }

  static List<Verse> _extractVerses(
    Map<String, dynamic> payload,
    String content,
  ) {
    final parsedVerses = _parseVerseList(payload['verses']);
    if (parsedVerses.isNotEmpty) {
      return parsedVerses;
    }

    if (content.isEmpty) {
      return const <Verse>[];
    }

    return _extractVersesFromContent(content);
  }

  static List<Verse> _extractVersesFromContent(String content) {
    final regex = RegExp(r'(?=\d{1,3}\s)');
    final chunks = content.split(regex);
    final verses = <Verse>[];
    var fallbackNumber = 1;

    for (final chunk in chunks) {
      final normalizedChunk = chunk.trim();
      if (normalizedChunk.isEmpty) {
        continue;
      }

      final match = RegExp(r'^(\d{1,3})\s+(.*)$').firstMatch(normalizedChunk);
      if (match != null) {
        final number = int.tryParse(match.group(1)!) ?? fallbackNumber;
        final text = _cleanText(match.group(2)!);
        if (text.isNotEmpty) {
          verses.add(Verse(number: number, text: text));
          fallbackNumber = number + 1;
        }
      } else {
        verses.add(Verse(number: fallbackNumber, text: normalizedChunk));
        fallbackNumber += 1;
      }
    }

    return verses;
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(value);
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

String? _nonEmptyString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

List<Verse> _parseVerseList(dynamic value) {
  if (value is! List) {
    return const <Verse>[];
  }

  final verses = <Verse>[];
  for (var i = 0; i < value.length; i += 1) {
    final item = value[i];
    if (item == null) {
      continue;
    }

    final fallbackNumber = i + 1;
    if (item is String) {
      final text = _cleanText(item);
      if (text.isNotEmpty) {
        verses.add(Verse(number: fallbackNumber, text: text));
      }
      continue;
    }

    final itemMap = _asMap(item);
    if (itemMap != null) {
      final verse = Verse.fromJson(itemMap, fallbackNumber: fallbackNumber);
      if (verse.text.isNotEmpty) {
        verses.add(verse);
      }
      continue;
    }

    final text = _cleanText(item.toString());
    if (text.isNotEmpty) {
      verses.add(Verse(number: fallbackNumber, text: text));
    }
  }

  return verses;
}

String _cleanText(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
