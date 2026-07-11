import 'package:bible_app/config/app_env.dart';
import 'package:bible_app/config/bible_languages.dart';
import 'package:bible_app/controllers/app_shell_controller.dart';
import 'package:bible_app/controllers/bible_controller.dart';
import 'package:bible_app/models/bible_book.dart';
import 'package:bible_app/models/bible_catalog.dart';
import 'package:bible_app/models/chapter_response.dart';
import 'package:bible_app/screens/bible/bible_page.dart';
import 'package:bible_app/services/bible_library_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await AppEnv.load();
  });

  testWidgets('Bible screen removes inline language bar and opens settings hub',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildBibleHarness(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bible'), findsOneWidget);
    expect(find.text('Genesis'), findsOneWidget);
    expect(find.text('Language'), findsNothing);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Bible settings'), findsOneWidget);
  });

  testWidgets('Reader opens navigator sheet from compact bottom bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildBibleHarness(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Genesis'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '1').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.unfold_more_rounded));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '1'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '2'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '3'), findsOneWidget);

    await tester.tap(find.text('Genesis').last);
    await tester.pumpAndSettle();

    expect(find.text('Choose a book, then a chapter.'), findsOneWidget);
    expect(find.text('Exodus'), findsOneWidget);
  });

  testWidgets('Reader long press opens verse action sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildBibleHarness(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Genesis'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '1').first);
    await tester.pumpAndSettle();

    final readerRect = tester.getRect(find.byType(SingleChildScrollView).first);
    await tester.longPressAt(
      Offset(readerRect.left + 96, readerRect.top + 72),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy text'), findsOneWidget);
    expect(find.text('Add to favorites'), findsOneWidget);
    expect(find.text('Highlight verse'), findsOneWidget);
    expect(find.text('Share verse'), findsOneWidget);
  });

  testWidgets('Downloads back returns to Bible settings sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildBibleHarness(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Bible settings'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final downloadsFinder = find.text('Downloads').last;
    await tester.ensureVisible(downloadsFinder);
    await tester.tap(downloadsFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Offline Library'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Bible settings'), findsOneWidget);
  });
}

Widget _buildBibleHarness() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppShellController>(
        create: (_) => AppShellController(),
      ),
      ChangeNotifierProvider<BibleController>(
        create: (_) => BibleController(
          libraryService: _FakeBibleLibraryService(),
        ),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: BiblePage(),
      ),
    ),
  );
}

class _FakeBibleLibraryService extends BibleLibraryService {
  @override
  Future<List<ResolvedBibleVersion>> listVersions(
    String languageCode, {
    bool forceRefresh = false,
  }) async {
    final language = bibleLanguageForCode(languageCode);
    return <ResolvedBibleVersion>[
      ResolvedBibleVersion(
        language: language,
        id: language.fallbackBibleId ?? 111,
        title: language.fallbackVersionTitle,
        abbreviation: language.fallbackAbbreviation,
        hasAudio: true,
        sourceLabel: language.fallbackSourceLabel,
        resolvedFromFallback: true,
      ),
    ];
  }

  @override
  Future<ResolvedBibleCatalog> loadCatalog(
    String languageCode, {
    bool forceRefresh = false,
    int? preferredVersionId,
  }) async {
    final language = bibleLanguageForCode(languageCode);
    return ResolvedBibleCatalog(
      language: language,
      version: ResolvedBibleVersion(
        language: language,
        id: preferredVersionId ?? language.fallbackBibleId ?? 111,
        title: language.fallbackVersionTitle,
        abbreviation: language.fallbackAbbreviation,
        hasAudio: true,
        sourceLabel: language.fallbackSourceLabel,
        resolvedFromFallback: true,
      ),
      books: const <BibleBook>[
        BibleBook(
          id: 'GEN',
          title: 'Genesis',
          fullTitle: 'Genesis',
          abbreviation: 'GEN',
          canon: 'OT',
          chapterCount: 3,
        ),
        BibleBook(
          id: 'EXO',
          title: 'Exodus',
          fullTitle: 'Exodus',
          abbreviation: 'EXO',
          canon: 'OT',
          chapterCount: 2,
        ),
      ],
      downloadedAt: DateTime(2026, 3, 19),
      fromCache: false,
    );
  }

  @override
  Future<ChapterResponse> loadChapter({
    required ResolvedBibleCatalog catalog,
    required String bookId,
    required String bookTitle,
    required int chapterNumber,
  }) async {
    return ChapterResponse(
      success: true,
      bibleId: catalog.version.id,
      passageId: '$bookId.$chapterNumber',
      content:
          '1 In the beginning God created the heavens and the earth. 2 Now the earth was formless.',
      audioUrl: 'https://example.com/$bookId.$chapterNumber.mp3',
      verses: const <Verse>[
        Verse(
          number: 1,
          text: 'In the beginning God created the heavens and the earth.',
        ),
        Verse(
          number: 2,
          text: 'Now the earth was formless and empty.',
        ),
      ],
    );
  }
}
