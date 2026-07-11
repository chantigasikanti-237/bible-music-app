import 'package:flutter/services.dart';

import 'dart:async';

import '../config/bible_book_metadata.dart';
import '../config/bible_languages.dart';
import '../models/bible_audio_profile.dart';
import '../models/bible_catalog.dart';
import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_version.dart';
import '../models/chapter_response.dart';
import '../repositories/youversion_repository.dart';
import 'bible_service.dart';
import 'offline_bible_service.dart';
import 'scripture_service.dart';
import 'youversion_api_service.dart';

class BibleLibraryService {
  BibleLibraryService({
    YouVersionRepository? youVersionRepository,
    YouVersionApiService? youVersionApiService,
    ScriptureService? scriptureService,
    OfflineBibleService? offlineBibleService,
    BibleService? bibleService,
  })  : _youVersionRepository = youVersionRepository ??
            YouVersionRepositoryImpl(YouVersionApiService()),
        _youVersionApiService = youVersionApiService ?? YouVersionApiService(),
        _scriptureService = scriptureService ?? ScriptureService(),
        _offlineBibleService = offlineBibleService ?? OfflineBibleService(),
        _bibleService = bibleService ?? BibleService();

  final YouVersionRepository _youVersionRepository;
  final YouVersionApiService _youVersionApiService;
  final ScriptureService _scriptureService;
  final OfflineBibleService _offlineBibleService;
  final BibleService _bibleService;

  final Map<String, ResolvedBibleCatalog> _catalogsByCacheKey =
      <String, ResolvedBibleCatalog>{};
  final Map<String, Future<ResolvedBibleCatalog>> _catalogFuturesByCacheKey =
      <String, Future<ResolvedBibleCatalog>>{};
  final Map<String, ResolvedBibleVersion> _resolvedVersionsByCacheKey =
      <String, ResolvedBibleVersion>{};
  final Map<String, List<ResolvedBibleVersion>> _availableVersionsByLanguage =
      <String, List<ResolvedBibleVersion>>{};
  final Map<String, List<Book>> _localBooksByLanguage = <String, List<Book>>{};
  final Map<String, Map<int, int>> _chapterVerseCountsByBook =
      <String, Map<int, int>>{};
  final Map<String, Future<Map<int, int>>> _chapterVerseCountFuturesByBook =
      <String, Future<Map<int, int>>>{};
  final Map<String, String> _audioSourcesByCacheKey = <String, String>{};
  final Map<String, Future<String?>> _audioSourceFuturesByCacheKey =
      <String, Future<String?>>{};
  final Set<String> _verifiedBundledAudioAssets = <String>{};
  final Set<String> _missingBundledAudioAssets = <String>{};

  static const Duration _publicChapterHedgeDelay = Duration(milliseconds: 900);

  Future<ResolvedBibleCatalog> loadCatalog(
    String languageCode, {
    bool forceRefresh = false,
    int? preferredVersionId,
  }) {
    final option = bibleLanguageForCode(languageCode);
    final requestedVersionId = _normalizedVersionId(preferredVersionId);
    final cacheKey = _catalogCacheKey(option.code, requestedVersionId);
    if (!forceRefresh) {
      final inMemoryCatalog = _catalogsByCacheKey[cacheKey];
      if (inMemoryCatalog != null) {
        return Future<ResolvedBibleCatalog>.value(inMemoryCatalog);
      }

      final pendingCatalog = _catalogFuturesByCacheKey[cacheKey];
      if (pendingCatalog != null) {
        return pendingCatalog;
      }
    }

    final future = _loadCatalogInternal(
      option,
      forceRefresh: forceRefresh,
      preferredVersionId: requestedVersionId,
    );
    if (!forceRefresh) {
      _catalogFuturesByCacheKey[cacheKey] = future;
    }
    return future.whenComplete(() {
      if (_catalogFuturesByCacheKey[cacheKey] == future) {
        _catalogFuturesByCacheKey.remove(cacheKey);
      }
    });
  }

  Future<ResolvedBibleCatalog> _loadCatalogInternal(
    BibleLanguageOption option, {
    required bool forceRefresh,
    required int? preferredVersionId,
  }) async {
    final cachedCatalog = _normalizeCatalog(
      await _offlineBibleService.getCatalog(
        option.code,
        versionId: preferredVersionId,
      ),
    );
    if (cachedCatalog != null &&
        cachedCatalog.books.isNotEmpty &&
        !_shouldRejectCatalogVersion(
          cachedCatalog,
          option,
          requestedVersionId: preferredVersionId,
        )) {
      if (!forceRefresh) {
        _persistCatalog(cachedCatalog);
      }
      _rememberCatalog(
        cachedCatalog,
        requestedVersionId: preferredVersionId,
      );
      return ResolvedBibleCatalog(
        language: cachedCatalog.language,
        version: cachedCatalog.version,
        books: cachedCatalog.books,
        downloadedAt: cachedCatalog.downloadedAt,
        fromCache: true,
      );
    }

    final catalog = await _buildCatalog(
      option,
      preferredVersionId: preferredVersionId,
    );
    _rememberCatalog(catalog, requestedVersionId: preferredVersionId);
    return catalog;
  }

  Future<List<ResolvedBibleVersion>> listVersions(
    String languageCode, {
    bool forceRefresh = false,
  }) async {
    final option = bibleLanguageForCode(languageCode);
    if (!forceRefresh &&
        _availableVersionsByLanguage.containsKey(option.code)) {
      return _availableVersionsByLanguage[option.code]!;
    }

    final resolved = <ResolvedBibleVersion>[];
    try {
      final remoteVersions = await _youVersionRepository.getBibleVersions(
        languageCode: option.code,
        audioOnly: false,
      );
      resolved.addAll(
        remoteVersions.map<ResolvedBibleVersion>(
          (BibleVersion version) => _resolvedVersionFromBibleVersion(
            option: option,
            version: version,
          ),
        ),
      );
      resolved.sort(
        (ResolvedBibleVersion a, ResolvedBibleVersion b) =>
            _scoreResolvedVersion(
          option: option,
          version: b,
          audioRequired: false,
        ).compareTo(
          _scoreResolvedVersion(
            option: option,
            version: a,
            audioRequired: false,
          ),
        ),
      );
    } catch (_) {}

    final fallback = _fallbackResolvedVersion(option);
    if (fallback != null &&
        !resolved.any((ResolvedBibleVersion item) => item.id == fallback.id)) {
      resolved.add(fallback);
    }

    if (resolved.isEmpty && fallback != null) {
      resolved.add(fallback);
    }

    final deduped = <ResolvedBibleVersion>[];
    final seenIds = <int>{};
    for (final version in resolved) {
      if (version.id <= 0 || seenIds.add(version.id)) {
        deduped.add(version);
      }
    }

    final immutable = List<ResolvedBibleVersion>.unmodifiable(deduped);
    _availableVersionsByLanguage[option.code] = immutable;
    return immutable;
  }

  Future<ResolvedBibleVersion> resolveVersion(
    String languageCode, {
    bool audioRequired = false,
    bool forceRefresh = false,
    int? preferredVersionId,
  }) async {
    final option = bibleLanguageForCode(languageCode);
    final requestedVersionId = _normalizedVersionId(preferredVersionId);
    final cacheKey = _versionCacheKey(option.code, requestedVersionId);
    if (!forceRefresh && _resolvedVersionsByCacheKey.containsKey(cacheKey)) {
      return _resolvedVersionsByCacheKey[cacheKey]!;
    }

    try {
      final versions = await listVersions(
        option.code,
        forceRefresh: forceRefresh,
      );
      if (versions.isNotEmpty) {
        final selected = requestedVersionId == null
            ? versions.first
            : versions.firstWhere(
                (ResolvedBibleVersion version) =>
                    version.id == requestedVersionId,
                orElse: () => versions.first,
              );
        _rememberResolvedVersion(
          selected,
          requestedVersionId: requestedVersionId,
        );
        return selected;
      }
    } catch (_) {
      final cachedCatalog = _normalizeCatalog(
        await _offlineBibleService.getCatalog(
          option.code,
          versionId: requestedVersionId,
        ),
      );
      if (cachedCatalog != null &&
          !_shouldRejectCatalogVersion(
            cachedCatalog,
            option,
            requestedVersionId: requestedVersionId,
          )) {
        _rememberResolvedVersion(
          cachedCatalog.version,
          requestedVersionId: requestedVersionId,
        );
        return cachedCatalog.version;
      }
    }

    final fallback = _fallbackResolvedVersion(option);
    if (fallback != null) {
      _rememberResolvedVersion(
        fallback,
        requestedVersionId: requestedVersionId,
      );
      return fallback;
    }

    throw StateError('No Bible version available for ${option.code}');
  }

  Future<ChapterResponse> loadChapter({
    required ResolvedBibleCatalog catalog,
    required String bookId,
    required String bookTitle,
    required int chapterNumber,
  }) async {
    final passageId = buildPassageId(bookId, chapterNumber);
    final cached = await _offlineBibleService.getChapter(
      languageCode: catalog.language.code,
      passageId: passageId,
      expectedVersionId: catalog.version.id,
    );
    if (cached != null) {
      return cached;
    }

    if (_shouldPreferLocalChapter(catalog)) {
      final localChapter = await _loadLocalChapter(
        catalog: catalog,
        bookId: bookId,
        bookTitle: bookTitle,
        chapterNumber: chapterNumber,
      );
      if (localChapter != null) {
        await _offlineBibleService.saveChapter(
          languageCode: catalog.language.code,
          passageId: passageId,
          bookId: bookId,
          bookTitle: bookTitle,
          chapterNumber: chapterNumber,
          version: catalog.version,
          chapter: localChapter,
        );
        return localChapter;
      }
    }

    final remoteChapter = await _loadFirstRemoteChapter(
      catalog: catalog,
      passageId: passageId,
    );
    if (remoteChapter != null) {
      await _offlineBibleService.saveChapter(
        languageCode: catalog.language.code,
        passageId: passageId,
        bookId: bookId,
        bookTitle: bookTitle,
        chapterNumber: chapterNumber,
        version: catalog.version,
        chapter: remoteChapter,
      );
      return remoteChapter;
    }

    final localChapter = await _loadLocalChapter(
      catalog: catalog,
      bookId: bookId,
      bookTitle: bookTitle,
      chapterNumber: chapterNumber,
    );
    if (localChapter != null) {
      await _offlineBibleService.saveChapter(
        languageCode: catalog.language.code,
        passageId: passageId,
        bookId: bookId,
        bookTitle: bookTitle,
        chapterNumber: chapterNumber,
        version: catalog.version,
        chapter: localChapter,
      );
      return localChapter;
    }

    throw StateError('Unable to load $passageId right now.');
  }

  Future<ChapterResponse?> _loadFirstRemoteChapter({
    required ResolvedBibleCatalog catalog,
    required String passageId,
  }) {
    final backendChapter = _scriptureService
        .fetchChapter(catalog.version.id, passageId)
        .then<ChapterResponse?>((ChapterResponse chapter) => chapter)
        .catchError((Object _) => null);
    final publicChapter = Future<ChapterResponse?>.delayed(
      _publicChapterHedgeDelay,
      () => _loadPublicChapter(
        catalog: catalog,
        passageId: passageId,
      ),
    ).catchError((Object _) => null);

    return _firstAvailableChapter(<Future<ChapterResponse?>>[
      backendChapter,
      publicChapter,
    ]);
  }

  Future<ChapterResponse?> _firstAvailableChapter(
    List<Future<ChapterResponse?>> futures,
  ) {
    if (futures.isEmpty) {
      return Future<ChapterResponse?>.value(null);
    }

    final completer = Completer<ChapterResponse?>();
    var pending = futures.length;

    void finishOne() {
      pending -= 1;
      if (pending == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    for (final future in futures) {
      future.then((ChapterResponse? chapter) {
        if (chapter != null && !completer.isCompleted) {
          completer.complete(chapter);
        }
      }).catchError((Object _) {
        // Each source is allowed to fail; another source may still win.
      }).whenComplete(finishOne);
    }

    return completer.future;
  }

  Future<Map<int, int>> loadChapterVerseCounts({
    required ResolvedBibleCatalog catalog,
    required String bookId,
    String? bookTitle,
    bool forceRefresh = false,
  }) {
    final normalizedBookId = bookId.trim().toUpperCase();
    final cacheKey =
        '${catalog.language.code}|${catalog.version.id}|$normalizedBookId';
    if (!forceRefresh) {
      final cachedVerseCounts = _chapterVerseCountsByBook[cacheKey];
      if (cachedVerseCounts != null) {
        return Future<Map<int, int>>.value(cachedVerseCounts);
      }

      final pendingVerseCounts = _chapterVerseCountFuturesByBook[cacheKey];
      if (pendingVerseCounts != null) {
        return pendingVerseCounts;
      }
    }

    final future = _loadChapterVerseCountsInternal(
      catalog: catalog,
      bookId: normalizedBookId,
      bookTitle: bookTitle,
    );
    if (!forceRefresh) {
      _chapterVerseCountFuturesByBook[cacheKey] = future;
    }
    return future.whenComplete(() {
      if (_chapterVerseCountFuturesByBook[cacheKey] == future) {
        _chapterVerseCountFuturesByBook.remove(cacheKey);
      }
    });
  }

  Future<String?> resolveAudioSource({
    required ResolvedBibleCatalog catalog,
    required String passageId,
    String? inlineAudioUrl,
  }) async {
    final normalizedPassageId = passageId.trim().toUpperCase();
    final cacheKey =
        '${catalog.language.code}|${catalog.version.id}|$normalizedPassageId';
    final cachedSource = _audioSourcesByCacheKey[cacheKey];
    if (cachedSource != null && cachedSource.isNotEmpty) {
      return cachedSource;
    }

    final pendingFuture = _audioSourceFuturesByCacheKey[cacheKey];
    if (pendingFuture != null) {
      return pendingFuture;
    }

    final future = _resolveAudioSourceInternal(
      catalog: catalog,
      passageId: normalizedPassageId,
      inlineAudioUrl: inlineAudioUrl,
    );
    _audioSourceFuturesByCacheKey[cacheKey] = future;
    return future.whenComplete(() {
      if (_audioSourceFuturesByCacheKey[cacheKey] == future) {
        _audioSourceFuturesByCacheKey.remove(cacheKey);
      }
    });
  }

  Future<void> downloadTextPackage({
    required ResolvedBibleCatalog catalog,
    String? bookId,
    String? bookTitle,
    int? chapterNumber,
  }) async {
    await _offlineBibleService.saveCatalog(catalog);
    if (bookId == null || bookTitle == null || chapterNumber == null) {
      return;
    }

    await loadChapter(
      catalog: catalog,
      bookId: bookId,
      bookTitle: bookTitle,
      chapterNumber: chapterNumber,
    );
  }

  Future<String> downloadAudioPackage({
    required ResolvedBibleCatalog catalog,
    required String passageId,
    String? inlineAudioUrl,
  }) async {
    final alreadyDownloaded = await _offlineBibleService.getAudioFilePath(
      languageCode: catalog.language.code,
      passageId: passageId,
      expectedVersionId: catalog.version.id,
    );
    if (alreadyDownloaded != null && alreadyDownloaded.isNotEmpty) {
      return alreadyDownloaded;
    }

    final audioSource = await resolveAudioSource(
      catalog: catalog,
      passageId: passageId,
      inlineAudioUrl: inlineAudioUrl,
    );
    if (audioSource == null || audioSource.isEmpty) {
      throw StateError('Audio is not available for $passageId');
    }

    if (audioSource.startsWith('assets/')) {
      // Only register a bundled asset that belongs to the target language.
      // _resolveAudioSourceInternal falls back to assets/audio/en/ for any
      // language without YouVersion audio and no same-language bundled asset,
      // which would silently store English narration under that language's key.
      if (!audioSource.startsWith('assets/audio/${catalog.language.code}/')) {
        throw StateError(
          'Audio is not available in ${catalog.version.sourceLabel} '
          'for $passageId',
        );
      }
      await _offlineBibleService.saveBundledAudio(
        languageCode: catalog.language.code,
        passageId: passageId,
        assetPath: audioSource,
        version: catalog.version,
      );
      return audioSource;
    }

    if (audioSource.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(audioSource)) {
      return audioSource;
    }

    return _offlineBibleService.downloadAudio(
      languageCode: catalog.language.code,
      passageId: passageId,
      audioUrl: audioSource,
      version: catalog.version,
    );
  }

  Future<OfflineLanguageStatus> getOfflineStatus({
    required String languageCode,
    String? passageId,
    int? expectedVersionId,
  }) {
    return _offlineBibleService.getStatus(
      languageCode: languageCode,
      passageId: passageId,
      expectedVersionId: _normalizedVersionId(expectedVersionId),
    );
  }

  Future<void> markLanguageDownloadComplete({
    required ResolvedBibleCatalog catalog,
    required int totalChapters,
  }) {
    return _offlineBibleService.markLanguageFullyDownloaded(
      languageCode: catalog.language.code,
      versionId: catalog.version.id,
      totalChapters: totalChapters,
    );
  }

  Future<bool> isLanguageFullyDownloaded(
    String languageCode, {
    int? expectedVersionId,
  }) {
    return _offlineBibleService.isLanguageFullyDownloaded(
      languageCode: languageCode,
      expectedVersionId: _normalizedVersionId(expectedVersionId),
    );
  }

  Future<String?> _resolveAudioSourceInternal({
    required ResolvedBibleCatalog catalog,
    required String passageId,
    String? inlineAudioUrl,
  }) async {
    final cacheKey =
        '${catalog.language.code}|${catalog.version.id}|${passageId.trim().toUpperCase()}';
    final cachedAudioPath = await _offlineBibleService.getAudioFilePath(
      languageCode: catalog.language.code,
      passageId: passageId,
      expectedVersionId: catalog.version.id,
    );
    if (cachedAudioPath != null && cachedAudioPath.isNotEmpty) {
      _audioSourcesByCacheKey[cacheKey] = cachedAudioPath;
      return cachedAudioPath;
    }

    final normalizedInlineUrl = inlineAudioUrl?.trim();
    if (normalizedInlineUrl != null && normalizedInlineUrl.isNotEmpty) {
      _audioSourcesByCacheKey[cacheKey] = normalizedInlineUrl;
      return normalizedInlineUrl;
    }

    try {
      final resolution = await _youVersionRepository.getChapterAudioResolution(
        bibleId: catalog.version.id,
        passageId: passageId,
        languageCode: catalog.language.code,
      );
      final remoteAudioUrl = resolution?.audioUrl;
      if (remoteAudioUrl != null && remoteAudioUrl.isNotEmpty) {
        _audioSourcesByCacheKey[cacheKey] = remoteAudioUrl;
        return remoteAudioUrl;
      }
    } catch (_) {}

    final bundledSource =
        await _resolveBundledAudioAsset(catalog.language.code, passageId);
    if (bundledSource != null && bundledSource.isNotEmpty) {
      _audioSourcesByCacheKey[cacheKey] = bundledSource;
    }
    return bundledSource;
  }

  List<BibleAudioProfile> resolveAudioProfiles(ResolvedBibleVersion version) {
    final extractedProfiles = _extractAudioProfiles(version.rawVersion?.audio);
    if (extractedProfiles.isEmpty) {
      return const <BibleAudioProfile>[
        BibleAudioProfile(
          id: 'default',
          label: 'Default narration',
          isDefault: true,
          isDramatized: false,
        ),
      ];
    }

    final dedupedProfiles = <BibleAudioProfile>[];
    final seenIds = <String>{};
    for (final profile in extractedProfiles) {
      if (seenIds.add(profile.id)) {
        dedupedProfiles.add(profile);
      }
    }

    if (!dedupedProfiles
        .any((BibleAudioProfile profile) => profile.isDefault)) {
      dedupedProfiles.insert(
        0,
        const BibleAudioProfile(
          id: 'default',
          label: 'Default narration',
          isDefault: true,
          isDramatized: false,
        ),
      );
    }

    return List<BibleAudioProfile>.unmodifiable(dedupedProfiles);
  }

  String buildPassageId(String bookId, int chapterNumber) =>
      '${bookId.trim().toUpperCase()}.$chapterNumber';

  ResolvedBibleVersion _resolvedVersionFromBibleVersion({
    required BibleLanguageOption option,
    required BibleVersion version,
  }) {
    final title =
        version.title.isNotEmpty ? version.title : option.fallbackSourceLabel;
    final abbreviation = version.abbreviation.isNotEmpty
        ? version.abbreviation
        : option.fallbackAbbreviation;

    return ResolvedBibleVersion(
      language: option,
      id: version.id,
      title: title,
      abbreviation: abbreviation,
      hasAudio: version.hasAudio,
      sourceLabel: '$abbreviation - $title',
      rawVersion: version,
    );
  }

  int _scoreVersion({
    required BibleLanguageOption option,
    required BibleVersion version,
    required bool audioRequired,
  }) {
    var score = 0;
    final haystack = '${version.abbreviation} ${version.title}'.toUpperCase();

    if (option.fallbackBibleId != null &&
        version.id == option.fallbackBibleId) {
      score += 240;
    }
    if (version.hasAudio) {
      score += 20;
    } else if (audioRequired) {
      score -= 40;
    }

    for (var index = 0;
        index < option.preferredVersionKeywords.length;
        index += 1) {
      final keyword = option.preferredVersionKeywords[index].toUpperCase();
      if (haystack.contains(keyword)) {
        score += 90 - index;
      }
    }

    return score;
  }

  int _scoreResolvedVersion({
    required BibleLanguageOption option,
    required ResolvedBibleVersion version,
    required bool audioRequired,
  }) {
    final rawVersion = version.rawVersion;
    if (rawVersion != null) {
      return _scoreVersion(
        option: option,
        version: rawVersion,
        audioRequired: audioRequired,
      );
    }

    var score = 0;
    final haystack = '${version.abbreviation} ${version.title}'.toUpperCase();
    if (option.fallbackBibleId != null &&
        version.id == option.fallbackBibleId) {
      score += 240;
    }
    if (version.hasAudio) {
      score += 20;
    } else if (audioRequired) {
      score -= 40;
    }
    for (var index = 0;
        index < option.preferredVersionKeywords.length;
        index += 1) {
      final keyword = option.preferredVersionKeywords[index].toUpperCase();
      if (haystack.contains(keyword)) {
        score += 90 - index;
      }
    }
    return score;
  }

  Future<ResolvedBibleCatalog> _buildCatalog(
    BibleLanguageOption option, {
    required int? preferredVersionId,
  }) async {
    ResolvedBibleVersion? resolvedVersion;
    try {
      resolvedVersion = await resolveVersion(
        option.code,
        preferredVersionId: preferredVersionId,
      );
      if (resolvedVersion.id > 0) {
        final remoteBooks = await _youVersionRepository.getBooksForBible(
          bibleId: resolvedVersion.id,
        );
        if (remoteBooks.isNotEmpty) {
          final catalog = _normalizeCatalog(
            ResolvedBibleCatalog(
              language: option,
              version: resolvedVersion,
              books: remoteBooks,
              downloadedAt: DateTime.now(),
              fromCache: false,
            ),
          )!;
          _persistCatalog(catalog);
          return catalog;
        }
      }
    } catch (_) {}

    final localBooks = await _loadLocalBooks(option.code);
    if (localBooks.isEmpty) {
      throw StateError('No offline Bible library is available right now.');
    }

    final resolvedLocalDataCode = _bibleService.resolveLocalDataLanguage(
      option.code,
    );
    final usesSampleLanguage = resolvedLocalDataCode != option.code;
    final sourceLabel = usesSampleLanguage
        ? 'Built-in offline sample (${bibleLanguageForCode(resolvedLocalDataCode).englishLabel})'
        : 'Built-in offline library';
    final version = resolvedVersion ??
        _fallbackResolvedVersion(option) ??
        ResolvedBibleVersion(
          language: option,
          id: option.fallbackBibleId ?? 0,
          title: sourceLabel,
          abbreviation: option.fallbackAbbreviation,
          hasAudio: _languageMayHaveStreamedAudio(option.code),
          sourceLabel: sourceLabel,
          resolvedFromFallback: true,
        );
    final catalog = ResolvedBibleCatalog(
      language: option,
      version: version,
      books: localBooks.length >= canonicalBibleBooks.length
          ? _mapLocalBooks(localBooks, option.code)
          : _buildCanonicalBooks(option.code),
      downloadedAt: DateTime.now(),
      fromCache: false,
    );
    _persistCatalog(catalog);
    return catalog;
  }

  void _persistCatalog(ResolvedBibleCatalog catalog) {
    unawaited(
      _offlineBibleService.saveCatalog(catalog).catchError((Object _) {}),
    );
  }

  void _rememberCatalog(
    ResolvedBibleCatalog catalog, {
    required int? requestedVersionId,
  }) {
    _catalogsByCacheKey[_catalogCacheKey(catalog.language.code, null)] =
        catalog;
    _catalogsByCacheKey[_catalogCacheKey(
      catalog.language.code,
      catalog.version.id,
    )] = catalog;
    if (requestedVersionId != null) {
      _catalogsByCacheKey[_catalogCacheKey(
        catalog.language.code,
        requestedVersionId,
      )] = catalog;
    }
    _rememberResolvedVersion(
      catalog.version,
      requestedVersionId: requestedVersionId,
    );
  }

  void _rememberResolvedVersion(
    ResolvedBibleVersion version, {
    required int? requestedVersionId,
  }) {
    _resolvedVersionsByCacheKey[_versionCacheKey(version.language.code, null)] =
        version;
    _resolvedVersionsByCacheKey[_versionCacheKey(
      version.language.code,
      version.id,
    )] = version;
    if (requestedVersionId != null) {
      _resolvedVersionsByCacheKey[_versionCacheKey(
        version.language.code,
        requestedVersionId,
      )] = version;
    }
  }

  String _catalogCacheKey(String languageCode, int? versionId) =>
      'catalog:${languageCode.trim().toLowerCase()}:${versionId ?? 'default'}';

  String _versionCacheKey(String languageCode, int? versionId) =>
      'version:${languageCode.trim().toLowerCase()}:${versionId ?? 'default'}';

  int? _normalizedVersionId(int? versionId) {
    if (versionId == null || versionId <= 0) {
      return null;
    }
    return versionId;
  }

  ResolvedBibleVersion? _fallbackResolvedVersion(BibleLanguageOption option) {
    final fallbackBibleId = option.fallbackBibleId;
    if (fallbackBibleId == null) {
      return null;
    }
    return ResolvedBibleVersion(
      language: option,
      id: fallbackBibleId,
      title: option.fallbackVersionTitle,
      abbreviation: option.fallbackAbbreviation,
      hasAudio: _languageMayHaveStreamedAudio(option.code),
      sourceLabel: option.fallbackSourceLabel,
      resolvedFromFallback: true,
    );
  }

  List<BibleAudioProfile> _extractAudioProfiles(dynamic rawAudio) {
    if (rawAudio is! Map) {
      return const <BibleAudioProfile>[];
    }

    final normalized = Map<String, dynamic>.from(rawAudio);
    final profiles = <BibleAudioProfile>[];

    void addProfile({
      required String id,
      required String label,
      required bool isDramatized,
      bool isDefault = false,
    }) {
      final normalizedId = id.trim().toLowerCase();
      if (normalizedId.isEmpty) {
        return;
      }
      profiles.add(
        BibleAudioProfile(
          id: normalizedId,
          label: label.trim().isEmpty ? 'Default narration' : label.trim(),
          isDefault: isDefault,
          isDramatized: isDramatized,
        ),
      );
    }

    bool containsUsableAudio(dynamic value) {
      return _extractProfileAudioUrl(value) != null || value == true;
    }

    BibleAudioProfile? profileFromMap(Map<String, dynamic> map) {
      final rawId = _firstNonEmptyString(
        <dynamic>[
          map['id'],
          map['profileId'],
          map['slug'],
          map['key'],
          map['type'],
          map['name'],
        ],
      );
      final rawLabel = _firstNonEmptyString(
        <dynamic>[
          map['label'],
          map['title'],
          map['displayName'],
          map['name'],
          map['text'],
        ],
      );
      final haystack = '${rawId ?? ''} ${rawLabel ?? ''} ${map['style'] ?? ''}'
          .toLowerCase();
      final isDramatized = haystack.contains('dramat');
      final isDefault = map['default'] == true ||
          map['is_default'] == true ||
          map['isDefault'] == true;
      final normalizedId = (rawId ??
              rawLabel ??
              (isDramatized
                  ? 'dramatized'
                  : isDefault
                      ? 'default'
                      : 'narration'))
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      if (normalizedId.isEmpty) {
        return null;
      }
      if (!containsUsableAudio(map) && rawLabel == null && rawId == null) {
        return null;
      }
      return BibleAudioProfile(
        id: normalizedId,
        label: rawLabel ??
            (isDramatized
                ? 'Dramatized'
                : isDefault
                    ? 'Default narration'
                    : 'Non-Dramatized'),
        isDefault: isDefault,
        isDramatized: isDramatized,
      );
    }

    for (final listKey in <String>[
      'profiles',
      'items',
      'options',
      'variants'
    ]) {
      final candidate = normalized[listKey];
      if (candidate is List) {
        for (final item in candidate.whereType<Map>()) {
          final parsed = profileFromMap(Map<String, dynamic>.from(item));
          if (parsed != null) {
            profiles.add(parsed);
          }
        }
      }
    }

    for (final key in <String>[
      'dramatized',
      'dramatised',
      'drama',
      'dramaAudio',
    ]) {
      if (containsUsableAudio(normalized[key])) {
        addProfile(
          id: 'dramatized',
          label: 'Dramatized',
          isDramatized: true,
        );
      }
    }
    for (final key in <String>[
      'nonDramatized',
      'non_dramatized',
      'standard',
      'plain',
    ]) {
      if (containsUsableAudio(normalized[key])) {
        addProfile(
          id: 'non-dramatized',
          label: 'Non-Dramatized',
          isDramatized: false,
        );
      }
    }

    if (profiles.isEmpty && containsUsableAudio(normalized)) {
      addProfile(
        id: 'default',
        label: 'Default narration',
        isDefault: true,
        isDramatized: false,
      );
    }

    return profiles;
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String? _extractProfileAudioUrl(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      return null;
    }
    if (value is List) {
      for (final item in value) {
        final extracted = _extractProfileAudioUrl(item);
        if (extracted != null) {
          return extracted;
        }
      }
      return null;
    }
    if (value is Map) {
      final normalized = Map<String, dynamic>.from(value);
      for (final key in <String>[
        'audio_url',
        'audioUrl',
        'url',
        'stream_url',
        'streamUrl',
        'src',
        'path',
      ]) {
        final extracted = _extractProfileAudioUrl(normalized[key]);
        if (extracted != null) {
          return extracted;
        }
      }
      for (final nestedValue in normalized.values) {
        final extracted = _extractProfileAudioUrl(nestedValue);
        if (extracted != null) {
          return extracted;
        }
      }
    }
    return null;
  }

  Future<List<Book>> _loadLocalBooks(String languageCode) async {
    final normalizedLanguageCode = languageCode.trim().toLowerCase();
    final cached = _localBooksByLanguage[normalizedLanguageCode];
    if (cached != null) {
      return cached;
    }

    final books = await _bibleService.getBible(normalizedLanguageCode);
    _localBooksByLanguage[normalizedLanguageCode] = books;
    return books;
  }

  List<BibleBook> _mapLocalBooks(
    List<Book> localBooks,
    String languageCode,
  ) {
    return localBooks.asMap().entries.map<BibleBook>(
      (entry) {
        final bookId = _buildLocalBookId(entry.value.name, entry.key);
        final metadata = bibleBookMetadataForId(bookId);
        final title =
            metadata?.titleForLanguage(languageCode) ?? entry.value.name.trim();

        return BibleBook(
          id: bookId,
          title: title,
          fullTitle: title,
          abbreviation: bookId,
          canon: metadata?.canon ?? (entry.key < 39 ? 'OT' : 'NT'),
          chapterCount: entry.value.chapterNumbers.length,
        );
      },
    ).toList(growable: false);
  }

  List<BibleBook> _buildCanonicalBooks(String languageCode) {
    return canonicalBibleBooks
        .map<BibleBook>(
          (BibleBookMetadata book) => BibleBook(
            id: book.id,
            title: book.titleForLanguage(languageCode),
            fullTitle: book.titleForLanguage(languageCode),
            abbreviation: book.id,
            canon: book.canon,
            chapterCount: book.chapterCount,
          ),
        )
        .toList(growable: false);
  }

  Future<ChapterResponse?> _loadLocalChapter({
    required ResolvedBibleCatalog catalog,
    required String bookId,
    required String bookTitle,
    required int chapterNumber,
  }) async {
    final localBook = await _findLocalBook(
      languageCode: catalog.language.code,
      bookId: bookId,
      bookTitle: bookTitle,
    );
    if (localBook == null) {
      return null;
    }

    final verses = localBook.chapters[chapterNumber];
    if (verses == null || verses.isEmpty) {
      return null;
    }

    final passageId = buildPassageId(bookId, chapterNumber);
    return ChapterResponse(
      success: true,
      bibleId: catalog.version.id,
      passageId: passageId,
      content: verses
          .map((Verse verse) => '${verse.number} ${verse.text}'.trim())
          .join('\n'),
      audioUrl: await _resolveBundledAudioAsset(
        catalog.language.code,
        passageId,
      ),
      verses: verses,
    );
  }

  Future<Map<int, int>> _loadChapterVerseCountsInternal({
    required ResolvedBibleCatalog catalog,
    required String bookId,
    String? bookTitle,
  }) async {
    final cacheKey =
        '${catalog.language.code}|${catalog.version.id}|${bookId.trim().toUpperCase()}';
    try {
      if (catalog.version.id > 0) {
        final chapters = await _youVersionRepository.getChaptersForBook(
          bibleId: catalog.version.id,
          bookId: bookId,
        );
        final verseCounts = _mapChapterVerseCounts(chapters, bookId);
        if (verseCounts.isNotEmpty) {
          final normalizedVerseCounts = Map<int, int>.unmodifiable(verseCounts);
          _chapterVerseCountsByBook[cacheKey] = normalizedVerseCounts;
          return normalizedVerseCounts;
        }
      }
    } catch (_) {}

    final localVerseCounts = await _loadLocalChapterVerseCounts(
      languageCode: catalog.language.code,
      bookId: bookId,
      bookTitle: bookTitle,
    );
    final normalizedLocalVerseCounts =
        Map<int, int>.unmodifiable(localVerseCounts);
    _chapterVerseCountsByBook[cacheKey] = normalizedLocalVerseCounts;
    return normalizedLocalVerseCounts;
  }

  Map<int, int> _mapChapterVerseCounts(
    List<BibleChapter> chapters,
    String bookId,
  ) {
    final verseCounts = <int, int>{};
    for (var index = 0; index < chapters.length; index += 1) {
      final chapter = chapters[index];
      final chapterNumber = _extractChapterNumber(chapter, bookId) ?? index + 1;
      if (chapterNumber > 0 && chapter.verseCount > 0) {
        verseCounts[chapterNumber] = chapter.verseCount;
      }
    }
    return verseCounts;
  }

  int? _extractChapterNumber(BibleChapter chapter, String bookId) {
    final normalizedBookId = bookId.trim().toUpperCase();
    final passageMatch = RegExp(
      '^${RegExp.escape(normalizedBookId)}\\.(\\d{1,3})\$',
    ).firstMatch(chapter.passageId.trim().toUpperCase());
    if (passageMatch != null) {
      return int.tryParse(passageMatch.group(1)!);
    }

    final directId = int.tryParse(chapter.id.trim());
    if (directId != null) {
      return directId;
    }

    final trailingDigits =
        RegExp(r'(\d{1,3})$').firstMatch(chapter.title.trim());
    if (trailingDigits == null) {
      return null;
    }

    return int.tryParse(trailingDigits.group(1)!);
  }

  Future<Map<int, int>> _loadLocalChapterVerseCounts({
    required String languageCode,
    required String bookId,
    String? bookTitle,
  }) async {
    final localBook = await _findLocalBook(
      languageCode: languageCode,
      bookId: bookId,
      bookTitle: bookTitle,
    );
    if (localBook == null) {
      return const <int, int>{};
    }

    final verseCounts = <int, int>{};
    for (final chapterNumber in localBook.chapterNumbers) {
      final verses = localBook.chapters[chapterNumber];
      if (verses != null && verses.isNotEmpty) {
        verseCounts[chapterNumber] = verses.length;
      }
    }
    return verseCounts;
  }

  Future<Book?> _findLocalBook({
    required String languageCode,
    required String bookId,
    String? bookTitle,
  }) async {
    final localBooks = await _loadLocalBooks(languageCode);
    if (localBooks.isEmpty) {
      return null;
    }

    final normalizedBookId = bookId.trim().toUpperCase();
    final normalizedBookTitle = bookTitle?.trim().toLowerCase();
    for (final entry in localBooks.asMap().entries) {
      final localBook = entry.value;
      final localBookId = _buildLocalBookId(localBook.name, entry.key);
      if (localBookId == normalizedBookId) {
        return localBook;
      }
      if (normalizedBookTitle != null &&
          localBook.name.trim().toLowerCase() == normalizedBookTitle) {
        return localBook;
      }
    }

    return null;
  }

  String _buildLocalBookId(String bookName, int index) {
    final trimmedBookName = bookName.trim();
    for (final BibleBookMetadata book in canonicalBibleBooks) {
      if (book.englishTitle.toLowerCase() == trimmedBookName.toLowerCase() ||
          book.teluguTitle == trimmedBookName) {
        return book.id;
      }
    }

    final normalizedAscii =
        trimmedBookName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalizedAscii.startsWith('GEN')) {
      return 'GEN';
    }
    if (normalizedAscii.startsWith('EXO')) {
      return 'EXO';
    }
    if (normalizedAscii.length >= 3) {
      return normalizedAscii.substring(0, 3);
    }
    return 'LOC${index + 1}';
  }

  bool _languageMayHaveStreamedAudio(String languageCode) {
    switch (languageCode.trim().toLowerCase()) {
      case 'en':
      case 'te':
      case 'hi':
      case 'ta':
      case 'kn':
      case 'ml':
      case 'mr':
        return true;
      default:
        return false;
    }
  }

  Future<String?> _resolveBundledAudioAsset(
    String languageCode,
    String passageId,
  ) async {
    final parsedPassage = _parsePassageId(passageId);
    if (parsedPassage == null) {
      return null;
    }

    final bookSlug = _bookSlugForPassage(parsedPassage.bookId);
    if (bookSlug == null) {
      return null;
    }

    final fallbackLanguageCode =
        _bibleService.resolveLocalDataLanguage(languageCode);
    final candidateLanguages = <String>{
      languageCode.trim().toLowerCase(),
      fallbackLanguageCode,
      'en',
    };
    for (final candidateLanguage in candidateLanguages) {
      final assetPath =
          'assets/audio/$candidateLanguage/${bookSlug}_${parsedPassage.chapterNumber}.mp3';
      if (await _bundledAssetExists(assetPath)) {
        return assetPath;
      }
    }
    return null;
  }

  String? _bookSlugForPassage(String bookId) {
    return bibleBookMetadataForId(bookId)?.audioSlug;
  }

  Future<bool> _bundledAssetExists(String assetPath) async {
    if (_verifiedBundledAudioAssets.contains(assetPath)) {
      return true;
    }
    if (_missingBundledAudioAssets.contains(assetPath)) {
      return false;
    }

    try {
      await rootBundle.load(assetPath);
      _verifiedBundledAudioAssets.add(assetPath);
      return true;
    } catch (_) {
      _missingBundledAudioAssets.add(assetPath);
      return false;
    }
  }

  _BundledPassage? _parsePassageId(String passageId) {
    final match =
        RegExp(r'^([A-Z0-9]{3,4})\.(\d{1,3})$').firstMatch(passageId.trim());
    if (match == null) {
      return null;
    }

    final chapterNumber = int.tryParse(match.group(2)!);
    if (chapterNumber == null) {
      return null;
    }

    return _BundledPassage(
      bookId: match.group(1)!,
      chapterNumber: chapterNumber,
    );
  }

  bool _shouldRejectCatalogVersion(
    ResolvedBibleCatalog catalog,
    BibleLanguageOption option, {
    required int? requestedVersionId,
  }) {
    if (requestedVersionId != null) {
      return catalog.version.id != requestedVersionId;
    }

    final preferredBibleId = option.fallbackBibleId;
    if (preferredBibleId == null) {
      return false;
    }

    return catalog.version.id != preferredBibleId;
  }

  ResolvedBibleCatalog? _normalizeCatalog(ResolvedBibleCatalog? catalog) {
    if (catalog == null || catalog.books.isEmpty) {
      return catalog;
    }

    final normalizedBooks = <BibleBook>[];
    final booksById = <String, BibleBook>{
      for (final BibleBook book in catalog.books)
        book.id.trim().toUpperCase(): book,
    };

    for (final BibleBookMetadata metadata in canonicalBibleBooks) {
      final title = metadata.titleForLanguage(catalog.language.code);
      final original = booksById[metadata.id];
      normalizedBooks.add(
        BibleBook(
          id: metadata.id,
          title: title,
          fullTitle: title,
          abbreviation: metadata.id,
          canon: metadata.canon,
          chapterCount: original?.chapterCount ?? metadata.chapterCount,
        ),
      );
    }

    if (normalizedBooks.isEmpty) {
      normalizedBooks.addAll(catalog.books);
    }

    return ResolvedBibleCatalog(
      language: catalog.language,
      version: catalog.version,
      books: normalizedBooks,
      downloadedAt: catalog.downloadedAt,
      fromCache: catalog.fromCache,
    );
  }

  Future<ChapterResponse?> _loadPublicChapter({
    required ResolvedBibleCatalog catalog,
    required String passageId,
  }) {
    if (catalog.version.id <= 0) {
      return Future<ChapterResponse?>.value(null);
    }

    return _youVersionApiService.fetchChapterFromBiblePage(
      bibleId: catalog.version.id,
      passageId: passageId,
      versionAbbreviation: catalog.version.abbreviation,
    );
  }

  bool _shouldPreferLocalChapter(ResolvedBibleCatalog catalog) {
    if (!catalog.version.resolvedFromFallback) {
      return false;
    }

    return _bibleService.resolveLocalDataLanguage(catalog.language.code) ==
        catalog.language.code;
  }
}

class _BundledPassage {
  const _BundledPassage({
    required this.bookId,
    required this.chapterNumber,
  });

  final String bookId;
  final int chapterNumber;
}
