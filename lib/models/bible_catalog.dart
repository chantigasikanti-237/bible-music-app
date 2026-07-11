import '../config/bible_languages.dart';
import 'bible_book.dart';
import 'bible_version.dart';

class ResolvedBibleVersion {
  const ResolvedBibleVersion({
    required this.language,
    required this.id,
    required this.title,
    required this.abbreviation,
    required this.hasAudio,
    required this.sourceLabel,
    this.rawVersion,
    this.resolvedFromFallback = false,
  });

  final BibleLanguageOption language;
  final int id;
  final String title;
  final String abbreviation;
  final bool hasAudio;
  final String sourceLabel;
  final BibleVersion? rawVersion;
  final bool resolvedFromFallback;

  factory ResolvedBibleVersion.fromJson(Map<String, dynamic> json) {
    final language =
        bibleLanguageForCode(json['languageCode']?.toString() ?? '');
    return ResolvedBibleVersion(
      language: language,
      id: json['id'] is int ? json['id'] as int : 0,
      title: json['title']?.toString() ?? '',
      abbreviation: json['abbreviation']?.toString() ?? '',
      hasAudio: json['hasAudio'] == true,
      sourceLabel:
          json['sourceLabel']?.toString() ?? language.fallbackSourceLabel,
      resolvedFromFallback: json['resolvedFromFallback'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'languageCode': language.code,
      'id': id,
      'title': title,
      'abbreviation': abbreviation,
      'hasAudio': hasAudio,
      'sourceLabel': sourceLabel,
      'resolvedFromFallback': resolvedFromFallback,
    };
  }
}

class ResolvedBibleCatalog {
  const ResolvedBibleCatalog({
    required this.language,
    required this.version,
    required this.books,
    required this.downloadedAt,
    required this.fromCache,
  });

  final BibleLanguageOption language;
  final ResolvedBibleVersion version;
  final List<BibleBook> books;
  final DateTime downloadedAt;
  final bool fromCache;

  factory ResolvedBibleCatalog.fromJson(Map<String, dynamic> json) {
    final language =
        bibleLanguageForCode(json['languageCode']?.toString() ?? '');
    final rawBooks = json['books'];
    final books = rawBooks is List
        ? rawBooks
            .whereType<Map>()
            .map<Map<String, dynamic>>(Map<String, dynamic>.from)
            .map(BibleBook.fromJson)
            .toList(growable: false)
        : const <BibleBook>[];

    return ResolvedBibleCatalog(
      language: language,
      version: ResolvedBibleVersion.fromJson(
        Map<String, dynamic>.from(
            json['version'] as Map? ?? const <String, dynamic>{}),
      ),
      books: books,
      downloadedAt: DateTime.tryParse(json['downloadedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fromCache: true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'languageCode': language.code,
      'version': version.toJson(),
      'books':
          books.map((BibleBook book) => book.toJson()).toList(growable: false),
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }
}
