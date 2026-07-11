import 'dart:async';

import 'package:bible_app/config/app_env.dart';
import 'package:bible_app/config/bible_book_metadata.dart';
import 'package:bible_app/config/bible_languages.dart';
import 'package:bible_app/models/bible_book.dart';
import 'package:bible_app/models/bible_catalog.dart';
import 'package:bible_app/models/bible_chapter.dart';
import 'package:bible_app/models/bible_version.dart';
import 'package:bible_app/models/chapter_response.dart';
import 'package:bible_app/repositories/youversion_repository.dart';
import 'package:bible_app/services/bible_library_service.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/services/offline_bible_service.dart';
import 'package:bible_app/services/scripture_service.dart';
import 'package:bible_app/services/youversion_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppEnv.load();
  });

  test(
    'fallback languages build a full localized canonical catalog',
    () async {
      final service = BibleLibraryService(
        youVersionRepository: _FakeYouVersionRepository(),
        offlineBibleService: _FakeOfflineBibleService(),
        bibleService: _FakeBibleService(),
      );

      final catalog = await service.loadCatalog('ta');

      expect(catalog.version.id, 339);
      expect(catalog.books, hasLength(66));
      expect(
        catalog.books.first.title,
        bibleBookMetadataForId('GEN')!.titleForLanguage('ta'),
      );
      expect(
        catalog.books[1].title,
        bibleBookMetadataForId('EXO')!.titleForLanguage('ta'),
      );
      expect(
        catalog.books.last.title,
        bibleBookMetadataForId('REV')!.titleForLanguage('ta'),
      );
    },
  );

  test(
    'stale cached sample catalogs are rejected for languages with pinned bible ids',
    () async {
      final language = bibleLanguageForCode('ml');
      final staleCatalog = ResolvedBibleCatalog(
        language: language,
        version: ResolvedBibleVersion(
          language: language,
          id: 0,
          title: 'Built-in offline sample (English)',
          abbreviation: 'IRVMAL',
          hasAudio: false,
          sourceLabel: 'Built-in offline sample (English)',
          resolvedFromFallback: true,
        ),
        books: <BibleBook>[
          const BibleBook(
            id: 'GEN',
            title: 'Genesis',
            fullTitle: 'Genesis',
            abbreviation: 'GEN',
            canon: 'OT',
            chapterCount: 50,
          ),
        ],
        downloadedAt: DateTime(2026, 3, 14),
        fromCache: true,
      );
      final service = BibleLibraryService(
        youVersionRepository: _FakeYouVersionRepository(),
        offlineBibleService: _FakeOfflineBibleService(
          catalogsByLanguage: <String, ResolvedBibleCatalog>{
            'ml': staleCatalog,
          },
        ),
        bibleService: _FakeBibleService(),
      );

      final catalog = await service.loadCatalog('ml');

      expect(catalog.version.id, 1693);
      expect(
        catalog.books.first.title,
        bibleBookMetadataForId('GEN')!.titleForLanguage('ml'),
      );
    },
  );

  test(
    'chapter verse counts come from chapter metadata when available',
    () async {
      final language = bibleLanguageForCode('mr');
      final service = BibleLibraryService(
        youVersionRepository: _FakeYouVersionRepository(
          chaptersByBibleAndBook: <String, List<BibleChapter>>{
            '1686|GEN': const <BibleChapter>[
              BibleChapter(
                id: '1',
                passageId: 'GEN.1',
                title: '1',
                verseCount: 30,
                audioUrl: null,
                audio: null,
              ),
              BibleChapter(
                id: '2',
                passageId: 'GEN.2',
                title: '2',
                verseCount: 25,
                audioUrl: null,
                audio: null,
              ),
            ],
          },
        ),
        offlineBibleService: _FakeOfflineBibleService(),
        bibleService: _FakeBibleService(),
      );

      final verseCounts = await service.loadChapterVerseCounts(
        catalog: ResolvedBibleCatalog(
          language: language,
          version: ResolvedBibleVersion(
            language: language,
            id: 1686,
            title: language.fallbackVersionTitle,
            abbreviation: language.fallbackAbbreviation,
            hasAudio: true,
            sourceLabel: language.fallbackSourceLabel,
            resolvedFromFallback: true,
          ),
          books: const <BibleBook>[],
          downloadedAt: DateTime(2026, 3, 15),
          fromCache: false,
        ),
        bookId: 'GEN',
        bookTitle: 'Genesis',
      );

      expect(verseCounts[1], 30);
      expect(verseCounts[2], 25);
    },
  );

  test(
    'chapter loading returns public page content when backend is slow',
    () async {
      final slowBackend = _SlowScriptureService();
      final publicPageService = _FastPublicPageService();
      final offlineService = _FakeOfflineBibleService();
      final language = bibleLanguageForCode('en');
      final service = BibleLibraryService(
        youVersionRepository: _FakeYouVersionRepository(),
        youVersionApiService: publicPageService,
        scriptureService: slowBackend,
        offlineBibleService: offlineService,
        bibleService: _FakeBibleService(),
      );

      final chapter = await service.loadChapter(
        catalog: ResolvedBibleCatalog(
          language: language,
          version: ResolvedBibleVersion(
            language: language,
            id: 111,
            title: language.fallbackVersionTitle,
            abbreviation: language.fallbackAbbreviation,
            hasAudio: true,
            sourceLabel: language.fallbackSourceLabel,
            resolvedFromFallback: false,
          ),
          books: const <BibleBook>[],
          downloadedAt: DateTime(2026, 5, 2),
          fromCache: false,
        ),
        bookId: 'JHN',
        bookTitle: 'John',
        chapterNumber: 3,
      );

      expect(chapter.passageId, 'JHN.3');
      expect(chapter.verses.single.text, 'For God so loved the world.');
      expect(publicPageService.requestedPassages, <String>['JHN.3']);
      expect(slowBackend.completed, isFalse);
      expect(offlineService.savedChapters, contains('en|JHN.3|111'));

      await slowBackend.done;
    },
  );
}

class _FakeYouVersionRepository implements YouVersionRepository {
  _FakeYouVersionRepository({
    this.chaptersByBibleAndBook = const <String, List<BibleChapter>>{},
  });

  final Map<String, List<BibleChapter>> chaptersByBibleAndBook;

  @override
  Future<List<BibleVersion>> getBibleVersions({
    String languageCode = 'en',
    bool audioOnly = false,
  }) async {
    return const <BibleVersion>[];
  }

  @override
  Future<List<BibleBook>> getBooksForBible({required int bibleId}) async {
    return const <BibleBook>[];
  }

  @override
  Future<List<BibleChapter>> getChaptersForBook({
    required int bibleId,
    required String bookId,
  }) async {
    return chaptersByBibleAndBook['$bibleId|${bookId.toUpperCase()}'] ??
        const <BibleChapter>[];
  }

  @override
  Future<String?> getChapterAudioUrl({
    required int bibleId,
    required String passageId,
    String? languageCode,
  }) async {
    return null;
  }

  @override
  Future<ChapterAudioResolution?> getChapterAudioResolution({
    required int bibleId,
    required String passageId,
    String? languageCode,
  }) async {
    return null;
  }
}

class _FakeOfflineBibleService extends OfflineBibleService {
  _FakeOfflineBibleService({
    this.catalogsByLanguage = const <String, ResolvedBibleCatalog>{},
  }) : super();

  final Map<String, ResolvedBibleCatalog> catalogsByLanguage;
  final Map<String, ChapterResponse> chaptersByKey =
      <String, ChapterResponse>{};
  final List<String> savedChapters = <String>[];

  @override
  Future<ResolvedBibleCatalog?> getCatalog(
    String languageCode, {
    int? versionId,
  }) async {
    return catalogsByLanguage[languageCode];
  }

  @override
  Future<void> saveCatalog(ResolvedBibleCatalog catalog) async {}

  @override
  Future<ChapterResponse?> getChapter({
    required String languageCode,
    required String passageId,
    int? expectedVersionId,
  }) async {
    return chaptersByKey['$languageCode|$passageId|$expectedVersionId'] ??
        chaptersByKey['$languageCode|$passageId|null'];
  }

  @override
  Future<void> saveChapter({
    required String languageCode,
    required String passageId,
    required String bookId,
    required String bookTitle,
    required int chapterNumber,
    required ResolvedBibleVersion version,
    required ChapterResponse chapter,
  }) async {
    final key = '$languageCode|$passageId|${version.id}';
    chaptersByKey[key] = chapter;
    savedChapters.add(key);
  }
}

class _FakeBibleService extends BibleService {
  @override
  String resolveLocalDataLanguage(String language) => 'en';

  @override
  Future<List<Book>> getBible(String language) async {
    return <Book>[
      Book(
        name: 'Genesis',
        chapters: <int, List<Verse>>{
          1: const <Verse>[Verse(number: 1, text: 'In the beginning')],
          2: const <Verse>[Verse(number: 1, text: 'Thus the heavens')],
        },
      ),
      Book(
        name: 'Exodus',
        chapters: <int, List<Verse>>{
          1: const <Verse>[Verse(number: 1, text: 'These are the names')],
        },
      ),
    ];
  }
}

class _SlowScriptureService extends ScriptureService {
  final Completer<void> _done = Completer<void>();
  bool completed = false;

  Future<void> get done => _done.future;

  @override
  Future<ChapterResponse> fetchChapter(int bibleId, String passageId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    completed = true;
    _done.complete();
    throw StateError('Backend was too slow');
  }
}

class _FastPublicPageService extends YouVersionApiService {
  final List<String> requestedPassages = <String>[];

  @override
  Future<ChapterResponse?> fetchChapterFromBiblePage({
    required int bibleId,
    required String passageId,
    required String versionAbbreviation,
  }) async {
    requestedPassages.add(passageId);
    return ChapterResponse(
      success: true,
      bibleId: bibleId,
      passageId: passageId,
      content: '1 For God so loved the world.',
      audioUrl: null,
      verses: const <Verse>[
        Verse(number: 1, text: 'For God so loved the world.'),
      ],
    );
  }
}
