import 'dart:async';

import 'package:bible_app/config/bible_languages.dart';
import 'package:bible_app/config/app_env.dart';
import 'package:bible_app/controllers/bible_controller.dart';
import 'package:bible_app/models/bible_book.dart';
import 'package:bible_app/models/bible_catalog.dart';
import 'package:bible_app/models/chapter_response.dart';
import 'package:bible_app/services/bible_library_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppEnv.load();
  });

  test(
    'language switching keeps the current books visible until the next catalog is ready',
    () async {
      final teluguCatalogCompleter = Completer<ResolvedBibleCatalog>();
      final libraryService = _FakeBibleLibraryService(
        <String, Future<ResolvedBibleCatalog>>{
          'en': Future<ResolvedBibleCatalog>.value(
            _catalog(languageCode: 'en', bookTitle: 'Genesis'),
          ),
          'te': teluguCatalogCompleter.future,
        },
      );
      final controller = BibleController(libraryService: libraryService);

      await controller.initialize();

      expect(controller.selectedLanguageCode, 'en');
      expect(controller.books, isNotEmpty);
      expect(controller.books.first.title, 'Genesis');

      final pendingSelection = controller.selectLanguage('te');
      await Future<void>.delayed(Duration.zero);

      expect(controller.catalogLoading, isTrue);
      expect(controller.selectedLanguageCode, 'en');
      expect(controller.books.first.title, 'Genesis');

      teluguCatalogCompleter.complete(
        _catalog(languageCode: 'te', bookTitle: 'ఆదికాండము'),
      );
      await pendingSelection;

      expect(controller.catalogLoading, isFalse);
      expect(controller.selectedLanguageCode, 'te');
      expect(controller.books, isNotEmpty);
      expect(controller.books.first.title, 'ఆదికాండము');
    },
  );
  test('reader text scale is clamped to supported bounds', () {
    final controller = BibleController(
      libraryService: _FakeBibleLibraryService(
        <String, Future<ResolvedBibleCatalog>>{
          'en': Future<ResolvedBibleCatalog>.value(
            _catalog(languageCode: 'en', bookTitle: 'Genesis'),
          ),
        },
      ),
    );

    controller.setReaderTextScale(0.5);
    expect(controller.readerTextScale, BibleController.minReaderTextScale);

    controller.setReaderTextScale(2.0);
    expect(controller.readerTextScale, BibleController.maxReaderTextScale);
  });

  test('reader verse highlights toggle using stable verse ids', () async {
    final controller = BibleController(
      libraryService: _FakeBibleLibraryService(
        <String, Future<ResolvedBibleCatalog>>{
          'en': Future<ResolvedBibleCatalog>.value(
            _catalog(languageCode: 'en', bookTitle: 'Genesis'),
          ),
        },
      ),
    );

    await controller.initialize();
    final currentBook = controller.books.first;
    controller.openReaderPassage(currentBook, 2);

    const verse =
        Verse(number: 4, text: 'Then God saw that the light was good.');
    final verseId = controller.buildVersePreferenceId(
      bookId: currentBook.id,
      chapterNumber: 2,
      verseNumber: verse.number,
    );

    expect(verseId, isNotNull);
    expect(
      controller.isVerseHighlighted(
        bookId: currentBook.id,
        chapterNumber: 2,
        verseNumber: verse.number,
      ),
      isFalse,
    );

    expect(
      controller.toggleVerseHighlight(
        bookId: currentBook.id,
        chapterNumber: 2,
        verse: verse,
      ),
      isTrue,
    );
    expect(controller.highlightedVerseIds, contains(verseId));
    expect(
      controller.isVerseHighlighted(
        bookId: currentBook.id,
        chapterNumber: 2,
        verseNumber: verse.number,
      ),
      isTrue,
    );

    expect(
      controller.toggleVerseHighlight(
        bookId: currentBook.id,
        chapterNumber: 2,
        verse: verse,
      ),
      isFalse,
    );
    expect(controller.highlightedVerseIds, isNot(contains(verseId)));
  });
}

class _FakeBibleLibraryService extends BibleLibraryService {
  _FakeBibleLibraryService(this._catalogs);

  final Map<String, Future<ResolvedBibleCatalog>> _catalogs;

  @override
  Future<ResolvedBibleCatalog> loadCatalog(
    String languageCode, {
    bool forceRefresh = false,
    int? preferredVersionId,
  }) {
    final normalizedCode = bibleLanguageForCode(languageCode).code;
    final catalog = _catalogs[normalizedCode];
    if (catalog == null) {
      throw StateError('Missing fake catalog for $normalizedCode');
    }
    return catalog;
  }
}

ResolvedBibleCatalog _catalog({
  required String languageCode,
  required String bookTitle,
}) {
  final language = bibleLanguageForCode(languageCode);
  return ResolvedBibleCatalog(
    language: language,
    version: ResolvedBibleVersion(
      language: language,
      id: language.fallbackBibleId ?? 1,
      title: language.fallbackVersionTitle,
      abbreviation: language.fallbackAbbreviation,
      hasAudio: false,
      sourceLabel: language.fallbackSourceLabel,
      resolvedFromFallback: true,
    ),
    books: <BibleBook>[
      BibleBook(
        id: 'GEN',
        title: bookTitle,
        fullTitle: bookTitle,
        abbreviation: 'GEN',
        canon: 'OT',
        chapterCount: 50,
      ),
    ],
    downloadedAt: DateTime(2026, 3, 12),
    fromCache: false,
  );
}
