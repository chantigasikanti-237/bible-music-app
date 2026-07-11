import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../config/bible_languages.dart';
import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_version.dart';
import '../models/chapter_response.dart';

class YouVersionApiException implements Exception {
  const YouVersionApiException(
    this.message, {
    this.statusCode,
    this.details,
  });

  final String message;
  final int? statusCode;
  final dynamic details;

  @override
  String toString() =>
      'YouVersionApiException(statusCode: $statusCode, message: $message)';
}

enum ChapterAudioSourcePath {
  youVersionV1,
  bibleComAudioPage,
}

class ChapterAudioResolution {
  const ChapterAudioResolution({
    required this.audioUrl,
    required this.sourcePath,
    required this.bibleId,
    required this.passageId,
    required this.fromCache,
  });

  final String audioUrl;
  final ChapterAudioSourcePath sourcePath;
  final int bibleId;
  final String passageId;
  final bool fromCache;
}

class YouVersionApiService {
  YouVersionApiService({
    http.Client? httpClient,
    String? appKey,
    Duration? timeout,
  })  : _httpClient = httpClient ?? http.Client(),
        _appKey = appKey?.trim() ?? '',
        _timeout = timeout ?? const Duration(seconds: 8);

  static const String _baseUrl = 'https://api.youversion.com/v1';
  static final Map<String, _AudioCacheEntry> _chapterAudioCache =
      <String, _AudioCacheEntry>{};
  static const Duration _chapterAudioCacheTtl = Duration(minutes: 30);

  final http.Client _httpClient;
  final String _appKey;
  final Duration _timeout;

  Future<List<BibleVersion>> fetchBibleVersions({
    String languageCode = 'en',
    bool audioOnly = false,
  }) async {
    final normalizedLanguageCode = languageCode.trim().toLowerCase();
    final payload = await _getJson(
      '/bibles',
      queryParameters: <String, String>{
        'language_ranges[]': normalizedLanguageCode,
      },
    );

    final items = _extractCollection(payload);
    final versions = items.map(BibleVersion.fromJson).toList(growable: false);

    if (!audioOnly) {
      return versions;
    }

    return versions
        .where((BibleVersion version) => version.hasAudio)
        .toList(growable: false);
  }

  Future<List<BibleBook>> fetchBooks({
    required int bibleId,
  }) async {
    final payload = await _getJson('/bibles/$bibleId/books');
    return _extractCollection(payload)
        .map(BibleBook.fromJson)
        .toList(growable: false);
  }

  Future<List<BibleChapter>> fetchChapters({
    required int bibleId,
    required String bookId,
  }) async {
    final normalizedBookId = bookId.trim().toUpperCase();
    if (normalizedBookId.isEmpty) {
      throw const YouVersionApiException('bookId is required');
    }

    final payload =
        await _getJson('/bibles/$bibleId/books/$normalizedBookId/chapters');
    return _extractCollection(payload)
        .map(BibleChapter.fromJson)
        .toList(growable: false);
  }

  Future<String?> fetchChapterAudioUrl({
    required int bibleId,
    required String passageId,
    String? languageCode,
  }) async {
    final resolution = await fetchChapterAudioResolution(
      bibleId: bibleId,
      passageId: passageId,
      languageCode: languageCode,
    );
    return resolution?.audioUrl;
  }

  Future<ChapterAudioResolution?> fetchChapterAudioResolution({
    required int bibleId,
    required String passageId,
    String? languageCode,
  }) async {
    final normalizedPassageId = passageId.trim().toUpperCase();
    if (normalizedPassageId.isEmpty) {
      throw const YouVersionApiException('passageId is required');
    }

    final cached = _getCachedChapterAudioResolution(
      bibleId: bibleId,
      passageId: normalizedPassageId,
      languageCode: languageCode,
    );
    if (cached != null) {
      return cached;
    }

    final candidates = <int>[
      bibleId,
    ];
    final preferredAudioBibleId = _preferredAudioBibleIdForLanguage(
      languageCode,
    );
    if (preferredAudioBibleId != null && preferredAudioBibleId != bibleId) {
      candidates.add(preferredAudioBibleId);
    }

    final parsedPassage = _parsePassageId(normalizedPassageId);
    YouVersionApiException? fatalError;

    for (final candidateBibleId in candidates) {
      final candidateCacheKey =
          _buildAudioCacheKey(candidateBibleId, normalizedPassageId);
      final cachedCandidate = _getCachedByKey(candidateCacheKey);
      if (cachedCandidate != null) {
        return ChapterAudioResolution(
          audioUrl: cachedCandidate.audioUrl,
          sourcePath: cachedCandidate.sourcePath,
          bibleId: candidateBibleId,
          passageId: normalizedPassageId,
          fromCache: true,
        );
      }

      if (parsedPassage != null) {
        try {
          final fromApi = await _fetchAudioFromApi(
            bibleId: candidateBibleId,
            bookId: parsedPassage.bookId,
            chapterId: parsedPassage.chapterId,
            passageId: normalizedPassageId,
          );
          if (fromApi != null && fromApi.isNotEmpty) {
            _setCachedByKey(
              candidateCacheKey,
              fromApi,
              ChapterAudioSourcePath.youVersionV1,
            );
            return ChapterAudioResolution(
              audioUrl: fromApi,
              sourcePath: ChapterAudioSourcePath.youVersionV1,
              bibleId: candidateBibleId,
              passageId: normalizedPassageId,
              fromCache: false,
            );
          }
        } on YouVersionApiException catch (error) {
          if (error.statusCode == 429) {
            rethrow;
          }

          final isFatal = error.statusCode == 401 || error.statusCode == 403;
          if (isFatal && fatalError == null) {
            fatalError = error;
          }
        }
      }

      final fromAudioPage = await _fetchAudioFromBibleAudioPage(
        bibleId: candidateBibleId,
        passageId: normalizedPassageId,
      );
      if (fromAudioPage != null && fromAudioPage.isNotEmpty) {
        _setCachedByKey(
          candidateCacheKey,
          fromAudioPage,
          ChapterAudioSourcePath.bibleComAudioPage,
        );
        return ChapterAudioResolution(
          audioUrl: fromAudioPage,
          sourcePath: ChapterAudioSourcePath.bibleComAudioPage,
          bibleId: candidateBibleId,
          passageId: normalizedPassageId,
          fromCache: false,
        );
      }
    }

    if (fatalError != null) {
      throw fatalError;
    }

    return null;
  }

  Future<ChapterResponse?> fetchChapterFromBiblePage({
    required int bibleId,
    required String passageId,
    required String versionAbbreviation,
  }) async {
    final normalizedPassageId = passageId.trim().toUpperCase();
    if (normalizedPassageId.isEmpty) {
      throw const YouVersionApiException('passageId is required');
    }

    final normalizedAbbreviation = versionAbbreviation.trim();
    final candidates = <Uri>[
      if (normalizedAbbreviation.isNotEmpty)
        Uri.parse(
          'https://www.bible.com/bible/$bibleId/$normalizedPassageId.$normalizedAbbreviation',
        ),
      Uri.parse('https://www.bible.com/bible/$bibleId/$normalizedPassageId'),
    ];

    for (final uri in candidates) {
      final response = await _getPublicPage(uri);
      if (response == null) {
        continue;
      }

      final nextDataJson = _extractNextDataJson(response.body);
      if (nextDataJson == null || nextDataJson.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(nextDataJson);
        if (decoded is! Map) {
          continue;
        }

        final root = Map<String, dynamic>.from(decoded);
        final pageProps = _asMap(_asMap(root['props'])?['pageProps']);
        final chapterInfo = _asMap(pageProps?['chapterInfo']);
        final chapterHtml = _asString(chapterInfo?['content']);
        if (chapterHtml == null || chapterHtml.isEmpty) {
          continue;
        }

        final verses = _extractVersesFromChapterHtml(chapterHtml);
        if (verses.isEmpty) {
          continue;
        }

        final versionData = _asMap(pageProps?['versionData']);
        final resolvedBibleId = _asInt(versionData?['id']) ?? bibleId;
        final audioUrl = _extractPublicPageAudioUrl(chapterInfo);
        return ChapterResponse(
          success: true,
          bibleId: resolvedBibleId,
          passageId: normalizedPassageId,
          content: verses
              .map((Verse verse) => '${verse.number} ${verse.text}'.trim())
              .join('\n'),
          audioUrl: audioUrl,
          verses: verses,
        );
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    _ensureAppKeyConfigured();

    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );

    http.Response response;
    try {
      response = await _httpClient.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'x-yvp-app-key': _appKey,
        },
      ).timeout(_timeout);
    } on TimeoutException {
      throw const YouVersionApiException('YouVersion request timed out');
    } on SocketException {
      throw const YouVersionApiException(
        'Unable to connect to YouVersion. Check internet connection.',
      );
    } catch (error) {
      throw YouVersionApiException('Unexpected YouVersion error: $error');
    }

    final decoded = _decodeResponse(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw _mapError(response.statusCode, decoded);
  }

  void _ensureAppKeyConfigured() {
    if (_appKey.isEmpty) {
      throw const YouVersionApiException(
        'Client-side YouVersion v1 access is disabled. Keep the key on the backend only.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is List) {
        return <String, dynamic>{'data': decoded};
      }
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{'raw': body};
    }
  }

  YouVersionApiException _mapError(
    int statusCode,
    Map<String, dynamic> payload,
  ) {
    final messageFromPayload = _extractMessage(payload);
    if (statusCode == 401 || statusCode == 403) {
      return YouVersionApiException(
        messageFromPayload ??
            'YouVersion denied access. Check app key permissions/licenses.',
        statusCode: statusCode,
        details: payload,
      );
    }

    if (statusCode == 404) {
      return YouVersionApiException(
        messageFromPayload ?? 'Requested YouVersion resource was not found.',
        statusCode: statusCode,
        details: payload,
      );
    }

    if (statusCode == 429) {
      return YouVersionApiException(
        messageFromPayload ??
            'YouVersion API rate limit reached. Try again shortly.',
        statusCode: statusCode,
        details: payload,
      );
    }

    return YouVersionApiException(
      messageFromPayload ?? 'YouVersion API request failed.',
      statusCode: statusCode,
      details: payload,
    );
  }

  String? _extractMessage(Map<String, dynamic> payload) {
    final candidate =
        payload['message'] ?? payload['detail'] ?? payload['error'];
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
    return null;
  }

  List<Map<String, dynamic>> _extractCollection(Map<String, dynamic> payload) {
    final dynamic data = payload['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map<Map<String, dynamic>>(Map<String, dynamic>.from)
          .toList(growable: false);
    }

    if (payload.isNotEmpty && payload['id'] != null) {
      return <Map<String, dynamic>>[Map<String, dynamic>.from(payload)];
    }

    return const <Map<String, dynamic>>[];
  }

  String? _extractAudioUrl(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      final normalized = _normalizeExternalUrl(value);
      if (normalized == null) {
        return null;
      }
      if (normalized.startsWith('http://') ||
          normalized.startsWith('https://')) {
        return normalized;
      }
      return null;
    }

    if (value is List) {
      for (final dynamic item in value) {
        final extracted = _extractAudioUrl(item);
        if (extracted != null) {
          return extracted;
        }
      }
      return null;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final preferredKeys = <String>[
        'audio_url',
        'audioUrl',
        'stream_url',
        'streamUrl',
        'url',
        'path',
        'src',
      ];
      for (final key in preferredKeys) {
        final extracted = _extractAudioUrl(map[key]);
        if (extracted != null) {
          return extracted;
        }
      }
      for (final dynamic nested in map.values) {
        final extracted = _extractAudioUrl(nested);
        if (extracted != null) {
          return extracted;
        }
      }
    }

    return null;
  }

  Future<String?> _fetchAudioFromApi({
    required int bibleId,
    required String bookId,
    required String chapterId,
    required String passageId,
  }) async {
    final chapterPayload =
        await _getJson('/bibles/$bibleId/books/$bookId/chapters/$chapterId');
    final chapterAudio = BibleChapter.fromJson(chapterPayload).audioUrl;
    if (chapterAudio != null && chapterAudio.isNotEmpty) {
      return chapterAudio;
    }

    final passagePayload =
        await _getJson('/bibles/$bibleId/passages/$passageId');
    final passageAudio = _extractAudioUrl(passagePayload);
    if (passageAudio != null && passageAudio.isNotEmpty) {
      return passageAudio;
    }

    return null;
  }

  Future<String?> _fetchAudioFromBibleAudioPage({
    required int bibleId,
    required String passageId,
  }) async {
    final uri =
        Uri.parse('https://www.bible.com/audio-bible/$bibleId/$passageId');
    final response = await _getPublicPage(uri);
    if (response == null) {
      return null;
    }

    final nextDataJson = _extractNextDataJson(response.body);
    if (nextDataJson == null || nextDataJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(nextDataJson);
      if (decoded is! Map) {
        return null;
      }

      final root = Map<String, dynamic>.from(decoded);
      final chapterInfo = _asMap(
        _asMap(
          _asMap(
            _asMap(root['props'])?['pageProps'],
          )?['chapterInfo'],
        ),
      );
      final audioChapterInfo = chapterInfo?['audioChapterInfo'];
      if (audioChapterInfo is! List || audioChapterInfo.isEmpty) {
        return null;
      }

      final firstAudio = _asMap(audioChapterInfo.first);
      final downloadUrls = _asMap(firstAudio?['download_urls']);
      if (downloadUrls == null) {
        return null;
      }

      final preferred = _normalizeExternalUrl(
            _asString(downloadUrls['format_mp3_64k']) ??
                _asString(downloadUrls['format_mp3_128k']) ??
                _asString(downloadUrls['format_mp3_32k']) ??
                _asString(downloadUrls['format_hls']),
          ) ??
          _extractAudioUrl(downloadUrls);

      return preferred;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response?> _getPublicPage(Uri uri) async {
    try {
      final response = await _httpClient
          .get(
            uri,
            headers: _publicPageHeaders(),
          )
          .timeout(_timeout);
      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode >= 500) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _publicPageHeaders() {
    return <String, String>{
      'Accept': 'text/html',
      'User-Agent':
          'Mozilla/5.0 (Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    };
  }

  List<Verse> _extractVersesFromChapterHtml(String html) {
    final fragment = html_parser.parseFragment(html);
    final verseTextByNumber = <int, StringBuffer>{};

    for (final verseElement in fragment.querySelectorAll('span.verse')) {
      final verseNumber = _parseVerseNumber(
            verseElement.attributes['data-usfm'],
          ) ??
          _parseVerseNumberFromLabel(verseElement.text);
      if (verseNumber == null) {
        continue;
      }

      final contentSegments = verseElement
          .querySelectorAll('span.content')
          .map((element) => _cleanPlainText(element.text))
          .where((text) => text.isNotEmpty)
          .toList(growable: false);
      final mergedSegment = _cleanPlainText(contentSegments.join(' '));
      if (mergedSegment.isEmpty) {
        continue;
      }

      final buffer =
          verseTextByNumber.putIfAbsent(verseNumber, () => StringBuffer());
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(mergedSegment);
    }

    final orderedEntries = verseTextByNumber.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    return orderedEntries
        .map(
          (entry) => Verse(
            number: entry.key,
            text: _cleanPlainText(entry.value.toString()),
          ),
        )
        .where((verse) => verse.text.isNotEmpty)
        .toList(growable: false);
  }

  int? _parseVerseNumber(String? usfm) {
    if (usfm == null || usfm.trim().isEmpty) {
      return null;
    }

    final parts = usfm.trim().split('.');
    if (parts.isEmpty) {
      return null;
    }
    return int.tryParse(parts.last);
  }

  int? _parseVerseNumberFromLabel(String rawText) {
    final match = RegExp(r'^\s*(\d{1,3})\b').firstMatch(rawText);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  String _cleanPlainText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _extractPublicPageAudioUrl(Map<String, dynamic>? chapterInfo) {
    final audioChapterInfo = chapterInfo?['audioChapterInfo'];
    if (audioChapterInfo is! List || audioChapterInfo.isEmpty) {
      return null;
    }

    final firstAudio = _asMap(audioChapterInfo.first);
    final downloadUrls = _asMap(firstAudio?['download_urls']);
    if (downloadUrls == null) {
      return null;
    }

    return _normalizeExternalUrl(
          _asString(downloadUrls['format_mp3_64k']) ??
              _asString(downloadUrls['format_mp3_128k']) ??
              _asString(downloadUrls['format_mp3_32k']) ??
              _asString(downloadUrls['format_hls']),
        ) ??
        _extractAudioUrl(downloadUrls);
  }

  String? _extractNextDataJson(String html) {
    final match = RegExp(
      r'<script id="__NEXT_DATA__" type="application/json">([\s\S]*?)</script>',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
  }

  _PassageId? _parsePassageId(String passageId) {
    final match = RegExp(r'^([A-Z0-9]{3,4})\.(\d{1,3})$').firstMatch(passageId);
    if (match == null) {
      return null;
    }

    return _PassageId(
      bookId: match.group(1)!,
      chapterId: match.group(2)!,
    );
  }

  String _buildAudioCacheKey(int bibleId, String passageId) =>
      '$bibleId|$passageId';

  int? _preferredAudioBibleIdForLanguage(String? languageCode) {
    final normalized = languageCode?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final option = bibleLanguageForCode(normalized);
    return option.fallbackAudioBibleId ?? option.fallbackBibleId;
  }

  ChapterAudioResolution? _getCachedChapterAudioResolution({
    required int bibleId,
    required String passageId,
    String? languageCode,
  }) {
    final direct = _getCachedByKey(_buildAudioCacheKey(bibleId, passageId));
    if (direct != null) {
      return ChapterAudioResolution(
        audioUrl: direct.audioUrl,
        sourcePath: direct.sourcePath,
        bibleId: bibleId,
        passageId: passageId,
        fromCache: true,
      );
    }

    final preferredAudioBibleId = _preferredAudioBibleIdForLanguage(
      languageCode,
    );
    if (preferredAudioBibleId == null || preferredAudioBibleId == bibleId) {
      return null;
    }
    final preferred = _getCachedByKey(
      _buildAudioCacheKey(preferredAudioBibleId, passageId),
    );
    if (preferred == null) {
      return null;
    }
    return ChapterAudioResolution(
      audioUrl: preferred.audioUrl,
      sourcePath: preferred.sourcePath,
      bibleId: preferredAudioBibleId,
      passageId: passageId,
      fromCache: true,
    );
  }

  _AudioCacheEntry? _getCachedByKey(String cacheKey) {
    final cached = _chapterAudioCache[cacheKey];
    if (cached == null) {
      return null;
    }

    if (DateTime.now().isAfter(cached.expiresAt)) {
      _chapterAudioCache.remove(cacheKey);
      return null;
    }

    return cached;
  }

  void _setCachedByKey(
    String cacheKey,
    String audioUrl,
    ChapterAudioSourcePath sourcePath,
  ) {
    _chapterAudioCache[cacheKey] = _AudioCacheEntry(
      audioUrl: audioUrl,
      sourcePath: sourcePath,
      expiresAt: DateTime.now().add(_chapterAudioCacheTtl),
    );
  }

  String? _normalizeExternalUrl(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    return trimmed;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
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
}

class _PassageId {
  const _PassageId({
    required this.bookId,
    required this.chapterId,
  });

  final String bookId;
  final String chapterId;
}

class _AudioCacheEntry {
  const _AudioCacheEntry({
    required this.audioUrl,
    required this.sourcePath,
    required this.expiresAt,
  });

  final String audioUrl;
  final ChapterAudioSourcePath sourcePath;
  final DateTime expiresAt;
}
