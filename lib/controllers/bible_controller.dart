import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/bible_book_metadata.dart';
import '../config/bible_languages.dart';
import '../models/bible_audio_profile.dart';
import '../models/bible_book.dart';
import '../models/bible_catalog.dart';
import '../models/chapter_response.dart';
import '../models/user_model.dart';
import '../services/bible_library_service.dart';
import '../services/offline_bible_service.dart';
import '../services/user_service.dart';
import '../services/verse_service.dart';
import '../utils/error_messages.dart';

enum BibleViewMode {
  books,
  chapters,
  reader,
}

class EnglishVerseLookupResult {
  const EnglishVerseLookupResult({
    required this.reference,
    required this.text,
    required this.versionLabel,
  });

  final String reference;
  final String text;
  final String versionLabel;
}

class BibleController extends ChangeNotifier {
  BibleController({
    BibleLibraryService? libraryService,
    VerseService? verseService,
  })  : _libraryService = libraryService ?? BibleLibraryService(),
        _verseService = verseService ?? VerseService();

  static const double minReaderTextScale = 0.85;
  static const double maxReaderTextScale = 1.75;

  final BibleLibraryService _libraryService;
  final VerseService _verseService;
  final Map<String, ResolvedBibleCatalog> _catalogByCacheKey =
      <String, ResolvedBibleCatalog>{};
  final Map<String, Future<ChapterResponse>> _chapterFutures =
      <String, Future<ChapterResponse>>{};
  final Map<String, List<ResolvedBibleVersion>> _availableVersionsByLanguage =
      <String, List<ResolvedBibleVersion>>{};

  UserService? _userService;
  BibleViewMode _viewMode = BibleViewMode.books;
  String _selectedLanguageCode = 'en';
  bool _catalogLoading = false;
  bool _immersiveMode = false;
  String? _catalogError;
  String? _selectedBookId;
  String? _selectedBookTitle;
  int _currentChapterNumber = 1;
  bool _initialized = false;
  int _catalogRequestId = 0;
  bool _catalogWarmupInProgress = false;
  Map<String, int> _selectedVersionIdByLanguage = <String, int>{};
  Map<String, bool> _audioEnabledByLanguage = <String, bool>{};
  Map<String, String> _audioProfileIdByLanguage = <String, String>{};
  Set<String> _highlightedVerseIds = <String>{};
  double _readerTextScale = 1;

  BibleViewMode get viewMode => _viewMode;
  String get selectedLanguageCode => _selectedLanguageCode;
  bool get catalogLoading => _catalogLoading;
  bool get immersiveMode => _immersiveMode;
  String? get catalogError => _catalogError;
  String? get selectedBookId => _selectedBookId;
  String? get selectedBookTitle => _selectedBookTitle;
  int get currentChapterNumber => _currentChapterNumber;
  bool get isInReader => _viewMode == BibleViewMode.reader;
  bool get isInitialized => _initialized;
  double get readerTextScale => _readerTextScale;
  Set<String> get highlightedVerseIds => Set<String>.unmodifiable(
        _highlightedVerseIds,
      );
  List<ResolvedBibleVersion> get availableVersions =>
      _availableVersionsByLanguage[_selectedLanguageCode] ??
      (currentCatalog == null
          ? const <ResolvedBibleVersion>[]
          : <ResolvedBibleVersion>[currentCatalog!.version]);

  ResolvedBibleCatalog? get currentCatalog {
    final explicitVersionId =
        _selectedVersionIdByLanguage[_selectedLanguageCode];
    return _catalogByCacheKey[_catalogCacheKey(
          _selectedLanguageCode,
          explicitVersionId,
        )] ??
        _catalogByCacheKey[_catalogCacheKey(_selectedLanguageCode, null)];
  }

  ResolvedBibleVersion? get currentVersion => currentCatalog?.version;
  bool get currentVersionSupportsAudio => currentVersion?.hasAudio ?? false;
  bool get isAudioEnabled =>
      _audioEnabledByLanguage[_selectedLanguageCode] ?? true;
  bool get canPlayCurrentAudio => currentVersionSupportsAudio && isAudioEnabled;

  List<BibleBook> get books => currentCatalog?.books ?? const <BibleBook>[];

  BibleBook? get currentBook {
    final bookId = _selectedBookId;
    if (bookId == null) {
      return null;
    }

    for (final BibleBook book in books) {
      if (book.id.toUpperCase() == bookId.toUpperCase()) {
        return book;
      }
    }
    return null;
  }

  List<BibleAudioProfile> get audioProfiles {
    final version = currentVersion;
    if (version == null) {
      return const <BibleAudioProfile>[
        BibleAudioProfile(
          id: 'default',
          label: 'Default narration',
          isDefault: true,
          isDramatized: false,
        ),
      ];
    }
    return _libraryService.resolveAudioProfiles(version);
  }

  String get selectedAudioProfileId {
    final selectedId = _audioProfileIdByLanguage[_selectedLanguageCode];
    final profiles = audioProfiles;
    if (selectedId != null &&
        profiles.any((BibleAudioProfile profile) => profile.id == selectedId)) {
      return selectedId;
    }
    return profiles.first.id;
  }

  int get currentBookChapterCount => currentBook?.chapterCount ?? 0;

  String? get currentPassageId {
    final bookId = _selectedBookId;
    if (bookId == null || bookId.isEmpty) {
      return null;
    }
    return _libraryService.buildPassageId(bookId, _currentChapterNumber);
  }

  void bindUserService(UserService userService) {
    _userService = userService;
    _syncPreferencesFromUser(userService.user);
  }

  Future<void> initialize({String? preferredLanguageCode}) async {
    if (_initialized && preferredLanguageCode == null) {
      return;
    }

    final nextLanguage = preferredLanguageCode == null
        ? bibleLanguageForCode(
            _userService?.user.bibleLanguage ?? _selectedLanguageCode,
          ).code
        : bibleLanguageForCode(preferredLanguageCode).code;
    _initialized = true;
    await _activateLanguage(nextLanguage, preserveLocation: false);
  }

  Future<void> refreshCatalog() => _activateLanguage(
        _selectedLanguageCode,
        preserveLocation: true,
        forceRefresh: true,
      );

  Future<void> ensureAvailableVersions({
    String? languageCode,
    bool forceRefresh = false,
  }) async {
    final normalizedLanguage = bibleLanguageForCode(
      languageCode ?? _selectedLanguageCode,
    ).code;
    final versions = await _libraryService.listVersions(
      normalizedLanguage,
      forceRefresh: forceRefresh,
    );
    _availableVersionsByLanguage[normalizedLanguage] = versions;
    final selectedVersionId = _selectedVersionIdByLanguage[normalizedLanguage];
    if (versions.isNotEmpty &&
        (selectedVersionId == null ||
            !versions.any(
              (ResolvedBibleVersion version) => version.id == selectedVersionId,
            ))) {
      _selectedVersionIdByLanguage = <String, int>{
        ..._selectedVersionIdByLanguage,
        normalizedLanguage: versions.first.id,
      };
      _userService?.setBibleVersionForLanguage(
        normalizedLanguage,
        versions.first.id,
      );
    }
    if (normalizedLanguage == _selectedLanguageCode) {
      _normalizeSelectedAudioProfileForCurrentLanguage(notify: true);
    }
  }

  Future<void> selectLanguage(
    String code, {
    bool preserveLocation = true,
    bool forceRefresh = false,
  }) async {
    final normalized = bibleLanguageForCode(code).code;
    await _activateLanguage(
      normalized,
      preserveLocation: preserveLocation,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> selectVersion(
    int versionId, {
    bool preserveLocation = true,
    bool forceRefresh = false,
  }) async {
    if (versionId <= 0) {
      return;
    }
    await _activateLanguage(
      _selectedLanguageCode,
      preserveLocation: preserveLocation,
      forceRefresh: forceRefresh,
      preferredVersionId: versionId,
    );
  }

  void setAudioEnabled(bool value) {
    if ((_audioEnabledByLanguage[_selectedLanguageCode] ?? true) == value) {
      return;
    }
    _audioEnabledByLanguage = <String, bool>{
      ..._audioEnabledByLanguage,
      _selectedLanguageCode: value,
    };
    _userService?.setBibleAudioEnabledForLanguage(_selectedLanguageCode, value);
    notifyListeners();
  }

  void selectAudioProfile(String profileId) {
    final normalizedProfileId = profileId.trim();
    if (normalizedProfileId.isEmpty) {
      return;
    }
    if (!audioProfiles.any(
      (BibleAudioProfile profile) => profile.id == normalizedProfileId,
    )) {
      return;
    }
    if (_audioProfileIdByLanguage[_selectedLanguageCode] ==
        normalizedProfileId) {
      return;
    }
    _audioProfileIdByLanguage = <String, String>{
      ..._audioProfileIdByLanguage,
      _selectedLanguageCode: normalizedProfileId,
    };
    _userService?.setBibleAudioProfileForLanguage(
      _selectedLanguageCode,
      normalizedProfileId,
    );
    notifyListeners();
  }

  void setReaderTextScale(double value) {
    final clamped = value.clamp(minReaderTextScale, maxReaderTextScale);
    if ((clamped - _readerTextScale).abs() < 0.001) {
      return;
    }
    _readerTextScale = clamped;
    _userService?.setBibleReaderTextScale(clamped);
    notifyListeners();
  }

  String? buildVersePreferenceId({
    required String bookId,
    required int chapterNumber,
    required int verseNumber,
    String? languageCode,
    int? versionId,
  }) {
    final normalizedBookId = bookId.trim().toUpperCase();
    final normalizedLanguage = bibleLanguageForCode(
      languageCode ?? _selectedLanguageCode,
    ).code;
    final resolvedVersionId = versionId ?? currentVersion?.id;
    if (normalizedBookId.isEmpty ||
        chapterNumber <= 0 ||
        verseNumber <= 0 ||
        resolvedVersionId == null ||
        resolvedVersionId <= 0) {
      return null;
    }

    final passageId = _libraryService
        .buildPassageId(normalizedBookId, chapterNumber)
        .trim()
        .toUpperCase();
    if (passageId.isEmpty) {
      return null;
    }
    return '$normalizedLanguage:$resolvedVersionId:$passageId:$verseNumber';
  }

  bool isVerseHighlighted({
    required String bookId,
    required int chapterNumber,
    required int verseNumber,
  }) {
    final verseId = buildVersePreferenceId(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
    );
    return verseId != null && _highlightedVerseIds.contains(verseId);
  }

  Set<int> highlightedVerseNumbersForChapter({
    required String bookId,
    required int chapterNumber,
    required Iterable<Verse> verses,
  }) {
    final highlighted = <int>{};
    for (final verse in verses) {
      if (isVerseHighlighted(
        bookId: bookId,
        chapterNumber: chapterNumber,
        verseNumber: verse.number,
      )) {
        highlighted.add(verse.number);
      }
    }
    return highlighted;
  }

  bool isVerseBookmarked({
    required String bookId,
    required int chapterNumber,
    required int verseNumber,
  }) {
    final userService = _userService;
    final verseId = buildVersePreferenceId(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
    );
    return userService != null &&
        verseId != null &&
        userService.user.bookmarkedVerses.contains(verseId);
  }

  bool toggleVerseHighlight({
    required String bookId,
    required int chapterNumber,
    required Verse verse,
  }) {
    final verseId = buildVersePreferenceId(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verse.number,
    );
    if (verseId == null) {
      return false;
    }

    final highlighted = !_highlightedVerseIds.contains(verseId);
    final nextHighlightedVerseIds = Set<String>.from(_highlightedVerseIds);
    if (highlighted) {
      nextHighlightedVerseIds.add(verseId);
      _userService?.addHighlightedVerse(verseId);
    } else {
      nextHighlightedVerseIds.remove(verseId);
      _userService?.removeHighlightedVerse(verseId);
    }
    _highlightedVerseIds = nextHighlightedVerseIds;
    notifyListeners();
    return highlighted;
  }

  void openBook(BibleBook book) {
    _selectedBookId = book.id;
    _selectedBookTitle = book.title;
    _currentChapterNumber = 1;
    _viewMode = BibleViewMode.chapters;
    _immersiveMode = false;
    notifyListeners();
  }

  void openReader(int chapterNumber) {
    _currentChapterNumber = chapterNumber;
    _viewMode = BibleViewMode.reader;
    notifyListeners();
  }

  void openReaderPassage(BibleBook book, int chapterNumber) {
    _selectedBookId = book.id;
    _selectedBookTitle = book.title;
    _currentChapterNumber = chapterNumber;
    _viewMode = BibleViewMode.reader;
    _immersiveMode = false;
    notifyListeners();
  }

  void goToChapter(int chapterNumber) {
    if (chapterNumber <= 0 || chapterNumber == _currentChapterNumber) {
      return;
    }
    _currentChapterNumber = chapterNumber;
    notifyListeners();
  }

  void showBooks() {
    _viewMode = BibleViewMode.books;
    _immersiveMode = false;
    notifyListeners();
  }

  void showChapters() {
    if (_selectedBookId == null) {
      _viewMode = BibleViewMode.books;
    } else {
      _viewMode = BibleViewMode.chapters;
    }
    _immersiveMode = false;
    notifyListeners();
  }

  bool handleBack() {
    if (_immersiveMode) {
      _immersiveMode = false;
      notifyListeners();
      return true;
    }

    switch (_viewMode) {
      case BibleViewMode.reader:
        showChapters();
        return true;
      case BibleViewMode.chapters:
        showBooks();
        return true;
      case BibleViewMode.books:
        return false;
    }
  }

  void setImmersiveMode(bool value) {
    if (_immersiveMode == value) {
      return;
    }
    _immersiveMode = value;
    notifyListeners();
  }

  void toggleImmersiveMode() => setImmersiveMode(!_immersiveMode);

  Future<ChapterResponse> loadCurrentChapter({bool forceRefresh = false}) {
    final book = currentBook;
    final catalog = currentCatalog;
    if (book == null || catalog == null) {
      throw StateError('Select a book and chapter before loading content.');
    }
    return loadChapter(
      bookId: book.id,
      bookTitle: book.title,
      chapterNumber: _currentChapterNumber,
      forceRefresh: forceRefresh,
    );
  }

  Future<ChapterResponse> loadChapter({
    required String bookId,
    required String bookTitle,
    required int chapterNumber,
    bool forceRefresh = false,
  }) {
    final catalog = currentCatalog;
    if (catalog == null) {
      throw StateError('Bible catalog is not loaded.');
    }

    final cacheKey =
        '${catalog.language.code}|${catalog.version.id}|${bookId.toUpperCase()}|$chapterNumber';
    if (!forceRefresh && _chapterFutures.containsKey(cacheKey)) {
      return _chapterFutures[cacheKey]!;
    }

    final future = _libraryService
        .loadChapter(
      catalog: catalog,
      bookId: bookId,
      bookTitle: bookTitle,
      chapterNumber: chapterNumber,
    )
        .catchError((Object error) {
      _chapterFutures.remove(cacheKey);
      throw error;
    });
    _chapterFutures[cacheKey] = future;
    return future;
  }

  void prefetchChaptersAround({
    BibleBook? book,
    int? chapterNumber,
    int radius = 1,
  }) {
    final catalog = currentCatalog;
    final targetBook = book ?? currentBook;
    final targetChapter = chapterNumber ?? _currentChapterNumber;
    if (catalog == null ||
        targetBook == null ||
        targetChapter <= 0 ||
        radius <= 0) {
      return;
    }

    for (var offset = -radius; offset <= radius; offset += 1) {
      final candidateChapter = targetChapter + offset;
      if (candidateChapter <= 0 || candidateChapter > targetBook.chapterCount) {
        continue;
      }

      unawaited(
        loadChapter(
          bookId: targetBook.id,
          bookTitle: targetBook.title,
          chapterNumber: candidateChapter,
        ).then((ChapterResponse chapter) async {
          if (!canPlayCurrentAudio) {
            return;
          }
          await _libraryService.resolveAudioSource(
            catalog: catalog,
            passageId: _libraryService.buildPassageId(
              targetBook.id,
              candidateChapter,
            ),
            inlineAudioUrl: chapter.audioUrl,
          );
        }).catchError((Object _) {}),
      );
    }
  }

  Future<ResolvedBibleCatalog> ensureCatalogForLanguage(
    String languageCode, {
    bool forceRefresh = false,
    int? preferredVersionId,
  }) async {
    final normalized = bibleLanguageForCode(languageCode).code;
    final requestedVersionId = _normalizedVersionId(
      preferredVersionId ?? _selectedVersionIdByLanguage[normalized],
    );
    final cacheKey = _catalogCacheKey(normalized, requestedVersionId);
    if (!forceRefresh && _catalogByCacheKey.containsKey(cacheKey)) {
      return _catalogByCacheKey[cacheKey]!;
    }

    final catalog = await _libraryService.loadCatalog(
      normalized,
      forceRefresh: forceRefresh,
      preferredVersionId: requestedVersionId,
    );
    _rememberCatalog(catalog);
    if (normalized == _selectedLanguageCode) {
      notifyListeners();
    }
    return catalog;
  }

  Future<OfflineLanguageStatus> getOfflineStatusForLanguage(
      String languageCode) {
    final normalized = bibleLanguageForCode(languageCode).code;
    return _libraryService.getOfflineStatus(
      languageCode: normalized,
      passageId: normalized == _selectedLanguageCode ? currentPassageId : null,
      expectedVersionId: _selectedVersionIdByLanguage[normalized],
    );
  }

  Future<bool> isWholeBibleDownloadedForLanguage(String languageCode) async {
    final normalized = bibleLanguageForCode(languageCode).code;
    return _libraryService.isLanguageFullyDownloaded(
      normalized,
      expectedVersionId: _selectedVersionIdByLanguage[normalized],
    );
  }

  Future<void> downloadTextForLanguage(String languageCode) async {
    final normalized = bibleLanguageForCode(languageCode).code;
    final catalog = await ensureCatalogForLanguage(
      normalized,
      preferredVersionId: _selectedVersionIdByLanguage[normalized],
    );
    final currentBookId = _selectedBookId;
    final currentBookTitle = _selectedBookTitle;
    final currentChapterNumber = _currentChapterNumber;
    await _libraryService.downloadTextPackage(
      catalog: catalog,
      bookId: currentBookId,
      bookTitle: currentBookTitle,
      chapterNumber: currentBookId == null ? null : currentChapterNumber,
    );
  }

  Future<String> downloadAudioForLanguage(
    String languageCode, {
    String? inlineAudioUrl,
  }) async {
    final currentPassageId = this.currentPassageId;
    if (currentPassageId == null) {
      throw StateError('Open a chapter before downloading audio.');
    }

    final normalized = bibleLanguageForCode(languageCode).code;
    final catalog = await ensureCatalogForLanguage(
      normalized,
      preferredVersionId: _selectedVersionIdByLanguage[normalized],
    );
    return _libraryService.downloadAudioPackage(
      catalog: catalog,
      passageId: currentPassageId,
      inlineAudioUrl: inlineAudioUrl,
    );
  }

  /// Downloads every chapter of [_selectedBookId] for [languageCode] —
  /// both text (via Hive) and audio (via local file).
  ///
  /// [onProgress] is called after each chapter completes with (done, total).
  /// [isCancelled] is polled before each chapter; return true to abort early.
  /// Audio failures per chapter are skipped; text failures abort the loop.
  Future<void> downloadBookForLanguage(
    String languageCode, {
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final bookId = _selectedBookId;
    if (bookId == null) {
      throw StateError('Open a book before downloading it.');
    }

    final normalized = bibleLanguageForCode(languageCode).code;
    final catalog = await ensureCatalogForLanguage(
      normalized,
      preferredVersionId: _selectedVersionIdByLanguage[normalized],
    );

    final book = catalog.books.cast<BibleBook?>().firstWhere(
          (BibleBook? b) => b?.id.toUpperCase() == bookId.toUpperCase(),
          orElse: () => null,
        );
    if (book == null) {
      throw StateError(
        'Book not found in the ${catalog.language.englishLabel} library.',
      );
    }

    final total = book.chapterCount;
    for (var ch = 1; ch <= total; ch++) {
      if (isCancelled()) return;

      await _libraryService.downloadTextPackage(
        catalog: catalog,
        bookId: book.id,
        bookTitle: book.title,
        chapterNumber: ch,
      );

      final passageId = _libraryService.buildPassageId(book.id, ch);
      try {
        await _libraryService.downloadAudioPackage(
          catalog: catalog,
          passageId: passageId,
        );
      } catch (_) {
        // Audio unavailable for this chapter — skip and continue with text.
      }

      onProgress(ch, total);
    }
  }

  /// Downloads every chapter of every book of the Bible for [languageCode] —
  /// both text (via Hive) and audio (via local file). This is
  /// [downloadBookForLanguage]'s inner loop wrapped in an outer loop over
  /// every book in the catalog, rather than just the currently open one.
  ///
  /// [onProgress] is called after each chapter completes with
  /// (chaptersDone, chaptersTotal, currentBookTitle).
  /// [isCancelled] is polled before each chapter; return true to abort early.
  /// Audio failures per chapter are skipped; text failures abort the loop.
  /// No-ops if the language is already fully downloaded for its current version.
  Future<void> downloadWholeBibleForLanguage(
    String languageCode, {
    required void Function(
      int chaptersDone,
      int chaptersTotal,
      String currentBookTitle,
    ) onProgress,
    required bool Function() isCancelled,
  }) async {
    final normalized = bibleLanguageForCode(languageCode).code;
    final catalog = await ensureCatalogForLanguage(
      normalized,
      preferredVersionId: _selectedVersionIdByLanguage[normalized],
    );

    final alreadyComplete = await _libraryService.isLanguageFullyDownloaded(
      normalized,
      expectedVersionId: catalog.version.id,
    );
    if (alreadyComplete) {
      return;
    }

    final totalChapters = catalog.books.fold<int>(
      0,
      (sum, book) => sum + book.chapterCount,
    );
    var chaptersDone = 0;

    for (final book in catalog.books) {
      for (var ch = 1; ch <= book.chapterCount; ch++) {
        if (isCancelled()) return;

        await _libraryService.downloadTextPackage(
          catalog: catalog,
          bookId: book.id,
          bookTitle: book.title,
          chapterNumber: ch,
        );

        final passageId = _libraryService.buildPassageId(book.id, ch);
        try {
          await _libraryService.downloadAudioPackage(
            catalog: catalog,
            passageId: passageId,
          );
        } catch (_) {
          // Audio unavailable for this chapter — skip and continue with text.
        }

        chaptersDone++;
        onProgress(chaptersDone, totalChapters, book.title);
      }
    }

    await _libraryService.markLanguageDownloadComplete(
      catalog: catalog,
      totalChapters: totalChapters,
    );
  }

  Future<String?> resolveAudioForCurrentChapter(String? inlineAudioUrl) async {
    final catalog = currentCatalog;
    final passageId = currentPassageId;
    if (catalog == null || passageId == null || !canPlayCurrentAudio) {
      return null;
    }

    return _libraryService.resolveAudioSource(
      catalog: catalog,
      passageId: passageId,
      inlineAudioUrl: inlineAudioUrl,
    );
  }

  Future<Map<int, int>> loadChapterVerseCounts({
    String? bookId,
    String? bookTitle,
    bool forceRefresh = false,
  }) {
    final catalog = currentCatalog;
    final selectedBook = currentBook;
    final resolvedBookId = (bookId ?? selectedBook?.id)?.trim();
    final resolvedBookTitle = bookTitle ?? selectedBook?.title;
    if (catalog == null || resolvedBookId == null || resolvedBookId.isEmpty) {
      return Future<Map<int, int>>.value(const <int, int>{});
    }

    return _libraryService.loadChapterVerseCounts(
      catalog: catalog,
      bookId: resolvedBookId,
      bookTitle: resolvedBookTitle,
      forceRefresh: forceRefresh,
    );
  }

  Future<Map<String, dynamic>> addBookmarkForVerse(
    Verse verse, {
    int? chapterNumber,
  }) async {
    final catalog = currentCatalog;
    final book = currentBook;
    final resolvedChapterNumber = chapterNumber ?? _currentChapterNumber;
    final passageId = book == null
        ? null
        : _libraryService.buildPassageId(book.id, resolvedChapterNumber);
    final userService = _userService;
    if (catalog == null || book == null || passageId == null) {
      throw StateError('Open a verse before adding it to bookmarks.');
    }

    if (userService == null) {
      throw StateError('Bookmark storage is not ready yet.');
    }

    final savedVerse = userService.saveVerseRecord(
      languageCode: catalog.language.code,
      bibleId: catalog.version.id,
      versionId: catalog.version.id,
      versionLabel: catalog.version.sourceLabel,
      bookId: book.id,
      bookTitle: book.title,
      chapterNumber: resolvedChapterNumber,
      verseNumber: verse.number,
      passageId: passageId,
      text: verse.text,
    );

    if (userService.user.authStatus == AuthStatus.loggedIn) {
      try {
        final response = await _verseService.saveVerse(
          bibleId: catalog.version.id,
          passageId: passageId,
          verseNumber: verse.number,
          text: verse.text,
        );
        final remoteId = response['_id']?.toString().trim();
        if (remoteId != null && remoteId.isNotEmpty) {
          userService.setSavedVerseRemoteId(savedVerse.id, remoteId);
        }
        return response.isEmpty ? savedVerse.toJson() : response;
      } catch (_) {}
    }

    return savedVerse.toJson();
  }

  Future<EnglishVerseLookupResult> lookupEnglishVerse(
    Verse verse, {
    int? chapterNumber,
  }) async {
    final book = currentBook;
    final resolvedChapterNumber = chapterNumber ?? _currentChapterNumber;
    final passageId = book == null
        ? null
        : _libraryService.buildPassageId(book.id, resolvedChapterNumber);
    if (book == null || passageId == null) {
      throw StateError('Open a chapter before translating a verse.');
    }

    final englishCatalog = await ensureCatalogForLanguage(
      'en',
      preferredVersionId: _selectedVersionIdByLanguage['en'],
    );
    final englishChapter = await _libraryService.loadChapter(
      catalog: englishCatalog,
      bookId: book.id,
      bookTitle: bibleBookMetadataForId(book.id)?.englishTitle ?? book.title,
      chapterNumber: resolvedChapterNumber,
    );
    final translatedVerse = englishChapter.verses.cast<Verse?>().firstWhere(
          (Verse? candidate) => candidate?.number == verse.number,
          orElse: () => null,
        );
    if (translatedVerse == null) {
      throw StateError('No matching English verse was found.');
    }

    final englishBookTitle =
        bibleBookMetadataForId(book.id)?.titleForLanguage('en') ?? book.title;
    return EnglishVerseLookupResult(
      reference: '$englishBookTitle $resolvedChapterNumber:${verse.number}',
      text: translatedVerse.text,
      versionLabel:
          '${englishCatalog.version.abbreviation} - ${englishCatalog.version.title}',
    );
  }

  String buildVerseShareText(
    Verse verse, {
    int? chapterNumber,
  }) {
    final catalog = currentCatalog;
    final book = currentBook;
    final resolvedChapterNumber = chapterNumber ?? _currentChapterNumber;
    final passageId = book == null
        ? null
        : _libraryService.buildPassageId(book.id, resolvedChapterNumber);
    if (catalog == null || book == null || passageId == null) {
      throw StateError('Open a verse before sharing it.');
    }

    final reference = '${book.title} $resolvedChapterNumber:${verse.number}';
    final chapterLink =
        'https://www.bible.com/bible/${catalog.version.id}/${Uri.encodeComponent(passageId)}';
    return '${verse.text}\n\n$reference\n$chapterLink';
  }

  Future<void> _activateLanguage(
    String languageCode, {
    required bool preserveLocation,
    bool forceRefresh = false,
    int? preferredVersionId,
  }) async {
    final normalized = bibleLanguageForCode(languageCode).code;
    final previousLanguageCode = _selectedLanguageCode;
    final requestedVersionId = _normalizedVersionId(
      preferredVersionId ?? _selectedVersionIdByLanguage[normalized],
    );
    final currentVersionId =
        normalized == _selectedLanguageCode ? currentCatalog?.version.id : null;
    final selectionChanged = normalized != previousLanguageCode ||
        requestedVersionId != currentVersionId;
    final hasLoadedCatalog = _catalogByCacheKey.containsKey(
      _catalogCacheKey(normalized, requestedVersionId),
    );
    if (!forceRefresh && !selectionChanged && hasLoadedCatalog) {
      return;
    }

    final requestId = ++_catalogRequestId;
    _catalogLoading = true;
    _catalogError = null;
    notifyListeners();

    try {
      final versions = await _libraryService.listVersions(normalized);
      _availableVersionsByLanguage[normalized] = versions;
      final effectiveVersionId = requestedVersionId != null &&
              versions.any(
                (ResolvedBibleVersion version) =>
                    version.id == requestedVersionId,
              )
          ? requestedVersionId
          : versions.isNotEmpty
              ? versions.first.id
              : requestedVersionId;

      final catalog = await _libraryService.loadCatalog(
        normalized,
        forceRefresh: forceRefresh,
        preferredVersionId: effectiveVersionId,
      );
      if (requestId != _catalogRequestId) {
        return;
      }

      _rememberCatalog(catalog);
      _selectedLanguageCode = normalized;
      _selectedVersionIdByLanguage = <String, int>{
        ..._selectedVersionIdByLanguage,
        normalized: catalog.version.id,
      };
      _userService?.setBibleLanguage(normalized);
      _userService?.setBibleVersionForLanguage(normalized, catalog.version.id);

      if (preserveLocation && _selectedBookId != null) {
        final localizedBook = _findBookById(_selectedBookId!);
        _selectedBookTitle = localizedBook?.title;
      }

      if (_selectedBookId != null && _findBookById(_selectedBookId!) == null) {
        _viewMode = BibleViewMode.books;
        _selectedBookId = null;
        _selectedBookTitle = null;
        _currentChapterNumber = 1;
      }

      _normalizeSelectedAudioProfileForCurrentLanguage();
      _scheduleCatalogWarmup(exceptLanguageCode: normalized);
    } catch (error) {
      if (requestId != _catalogRequestId) {
        return;
      }
      _catalogError = formatDisplayError(error);
    } finally {
      if (requestId == _catalogRequestId) {
        _catalogLoading = false;
        notifyListeners();
      }
    }
  }

  void _scheduleCatalogWarmup({required String exceptLanguageCode}) {
    final warmedLanguages = _catalogByCacheKey.keys
        .map((String key) => key.split(':').first)
        .toSet();
    if (_catalogWarmupInProgress ||
        warmedLanguages.length >= bibleLanguageOptions.length) {
      return;
    }

    unawaited(
      _warmCatalogsInBackground(exceptLanguageCode: exceptLanguageCode),
    );
  }

  Future<void> _warmCatalogsInBackground({
    required String exceptLanguageCode,
  }) async {
    if (_catalogWarmupInProgress) {
      return;
    }

    _catalogWarmupInProgress = true;
    try {
      for (final BibleLanguageOption option in bibleLanguageOptions) {
        if (option.code == exceptLanguageCode) {
          continue;
        }

        try {
          final preferredVersionId = _selectedVersionIdByLanguage[option.code];
          final catalog = await _libraryService.loadCatalog(
            option.code,
            preferredVersionId: preferredVersionId,
          );
          _rememberCatalog(catalog);
          _availableVersionsByLanguage.putIfAbsent(
            option.code,
            () => const <ResolvedBibleVersion>[],
          );
        } catch (_) {}
      }
    } finally {
      _catalogWarmupInProgress = false;
    }
  }

  void _rememberCatalog(ResolvedBibleCatalog catalog) {
    _catalogByCacheKey[_catalogCacheKey(catalog.language.code, null)] = catalog;
    _catalogByCacheKey[
        _catalogCacheKey(catalog.language.code, catalog.version.id)] = catalog;
  }

  void _normalizeSelectedAudioProfileForCurrentLanguage({
    bool notify = false,
  }) {
    final profiles = audioProfiles;
    if (profiles.isEmpty) {
      return;
    }
    final selectedProfileId = _audioProfileIdByLanguage[_selectedLanguageCode];
    if (selectedProfileId != null &&
        profiles.any(
            (BibleAudioProfile profile) => profile.id == selectedProfileId)) {
      return;
    }
    _audioProfileIdByLanguage = <String, String>{
      ..._audioProfileIdByLanguage,
      _selectedLanguageCode: profiles.first.id,
    };
    _userService?.setBibleAudioProfileForLanguage(
      _selectedLanguageCode,
      profiles.first.id,
    );
    if (notify) {
      notifyListeners();
    }
  }

  void _syncPreferencesFromUser(UserModel user) {
    final normalizedLanguage = bibleLanguageForCode(user.bibleLanguage).code;
    final normalizedVersionIds = <String, int>{
      for (final entry in user.bibleVersionIdsByLanguage.entries)
        if (entry.key.trim().isNotEmpty && entry.value > 0)
          entry.key.trim().toLowerCase(): entry.value,
    };
    final normalizedAudioEnabled = <String, bool>{
      for (final entry in user.bibleAudioEnabledByLanguage.entries)
        if (entry.key.trim().isNotEmpty)
          entry.key.trim().toLowerCase(): entry.value,
    };
    final normalizedAudioProfiles = <String, String>{
      for (final entry in user.bibleAudioProfileByLanguage.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key.trim().toLowerCase(): entry.value.trim(),
    };
    final normalizedHighlightedVerseIds = user.highlightedVerses
        .map((String verseId) => verseId.trim())
        .where((String verseId) => verseId.isNotEmpty)
        .toSet();
    final nextReaderTextScale = user.bibleReaderTextScale.clamp(
      minReaderTextScale,
      maxReaderTextScale,
    );

    final prefsChanged =
        !mapEquals(_selectedVersionIdByLanguage, normalizedVersionIds) ||
            !mapEquals(_audioEnabledByLanguage, normalizedAudioEnabled) ||
            !mapEquals(_audioProfileIdByLanguage, normalizedAudioProfiles) ||
            !setEquals(_highlightedVerseIds, normalizedHighlightedVerseIds) ||
            (_readerTextScale - nextReaderTextScale).abs() >= 0.001;

    _selectedVersionIdByLanguage = normalizedVersionIds;
    _audioEnabledByLanguage = normalizedAudioEnabled;
    _audioProfileIdByLanguage = normalizedAudioProfiles;
    _highlightedVerseIds = normalizedHighlightedVerseIds;
    _readerTextScale = nextReaderTextScale;

    if (!_initialized) {
      _selectedLanguageCode = normalizedLanguage;
    } else if (normalizedLanguage != _selectedLanguageCode &&
        !_catalogLoading) {
      unawaited(
        _activateLanguage(
          normalizedLanguage,
          preserveLocation: true,
        ),
      );
    }

    if (prefsChanged) {
      _normalizeSelectedAudioProfileForCurrentLanguage();
      notifyListeners();
    }
  }

  BibleBook? _findBookById(String bookId) {
    for (final BibleBook book in books) {
      if (book.id.toUpperCase() == bookId.toUpperCase()) {
        return book;
      }
    }
    return null;
  }

  String _catalogCacheKey(String languageCode, int? versionId) =>
      '${languageCode.trim().toLowerCase()}:${versionId ?? 'default'}';

  int? _normalizedVersionId(int? versionId) {
    if (versionId == null || versionId <= 0) {
      return null;
    }
    return versionId;
  }
}
