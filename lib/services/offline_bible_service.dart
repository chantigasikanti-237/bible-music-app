import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/bible_catalog.dart';
import '../models/chapter_response.dart';

class OfflineLanguageStatus {
  const OfflineLanguageStatus({
    required this.hasCatalog,
    required this.hasCurrentText,
    required this.hasCurrentAudio,
    this.audioPath,
    this.chapterCachedAt,
    this.audioCachedAt,
  });

  final bool hasCatalog;
  final bool hasCurrentText;
  final bool hasCurrentAudio;
  final String? audioPath;
  final DateTime? chapterCachedAt;
  final DateTime? audioCachedAt;
}

class OfflineBibleService {
  OfflineBibleService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static const String _boxName = 'offline_bible';
  final http.Client _httpClient;

  Future<void> saveCatalog(ResolvedBibleCatalog catalog) async {
    final box = await _box();
    await box.put(
      _catalogKey(
        catalog.language.code,
        versionId: catalog.version.id,
      ),
      catalog.toJson(),
    );
    await box.put(
      _catalogKey(catalog.language.code),
      catalog.toJson(),
    );
  }

  Future<ResolvedBibleCatalog?> getCatalog(
    String languageCode, {
    int? versionId,
  }) async {
    final box = await _box();
    final requestedVersionId = _normalizedVersionId(versionId);
    for (final key in _catalogLookupKeys(languageCode, requestedVersionId)) {
      final raw = box.get(key);
      if (raw is! Map) {
        continue;
      }

      final catalog = ResolvedBibleCatalog.fromJson(Map<String, dynamic>.from(raw));
      if (requestedVersionId == null || catalog.version.id == requestedVersionId) {
        return catalog;
      }
    }
    return null;
  }

  Future<void> markLanguageFullyDownloaded({
    required String languageCode,
    required int versionId,
    required int totalChapters,
  }) async {
    final box = await _box();
    final value = <String, dynamic>{
      'languageCode': languageCode,
      'versionId': versionId,
      'totalChapters': totalChapters,
      'completedAt': DateTime.now().toIso8601String(),
    };
    await box.put(_languageCompleteKey(languageCode), value);
    await box.put(
      _languageCompleteKey(languageCode, versionId: versionId),
      value,
    );
  }

  Future<bool> isLanguageFullyDownloaded({
    required String languageCode,
    int? expectedVersionId,
  }) async {
    final box = await _box();
    for (final key in _languageCompleteLookupKeys(
      languageCode,
      _normalizedVersionId(expectedVersionId),
    )) {
      final raw = box.get(key);
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      if (!_matchesExpectedVersion(
        <String, dynamic>{'id': map['versionId']},
        expectedVersionId,
      )) {
        continue;
      }
      return true;
    }
    return false;
  }

  Future<void> saveChapter({
    required String languageCode,
    required String passageId,
    required String bookId,
    required String bookTitle,
    required int chapterNumber,
    required ResolvedBibleVersion version,
    required ChapterResponse chapter,
  }) async {
    final box = await _box();
    await box.put(
      _chapterKey(languageCode, passageId),
      <String, dynamic>{
        'languageCode': languageCode,
        'passageId': passageId,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'chapterNumber': chapterNumber,
        'version': version.toJson(),
        'chapter': chapter.toJson(),
        'downloadedAt': DateTime.now().toIso8601String(),
      },
    );
    await box.put(
      _chapterKey(
        languageCode,
        passageId,
        versionId: version.id,
      ),
      <String, dynamic>{
        'languageCode': languageCode,
        'passageId': passageId,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'chapterNumber': chapterNumber,
        'version': version.toJson(),
        'chapter': chapter.toJson(),
        'downloadedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<ChapterResponse?> getChapter({
    required String languageCode,
    required String passageId,
    int? expectedVersionId,
  }) async {
    final box = await _box();
    for (final key in _chapterLookupKeys(
      languageCode,
      passageId,
      _normalizedVersionId(expectedVersionId),
    )) {
      final raw = box.get(key);
      if (raw is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(raw);
      if (!_matchesExpectedVersion(map['version'], expectedVersionId)) {
        continue;
      }
      final chapterMap = Map<String, dynamic>.from(
        map['chapter'] as Map? ?? const <String, dynamic>{},
      );
      if (chapterMap.isEmpty) {
        continue;
      }

      return ChapterResponse.fromJson(
        chapterMap,
        fallbackBibleId: (chapterMap['bibleId'] as int?) ?? 0,
        fallbackPassageId: passageId,
      );
    }
    return null;
  }

  Future<DateTime?> getChapterDownloadedAt({
    required String languageCode,
    required String passageId,
    int? expectedVersionId,
  }) async {
    final box = await _box();
    for (final key in _chapterLookupKeys(
      languageCode,
      passageId,
      _normalizedVersionId(expectedVersionId),
    )) {
      final raw = box.get(key);
      if (raw is! Map) {
        continue;
      }

      if (!_matchesExpectedVersion(raw['version'], expectedVersionId)) {
        continue;
      }

      return DateTime.tryParse(raw['downloadedAt']?.toString() ?? '');
    }
    return null;
  }

  Future<String?> getAudioFilePath({
    required String languageCode,
    required String passageId,
    int? expectedVersionId,
  }) async {
    final box = await _box();
    for (final key in _audioLookupKeys(
      languageCode,
      passageId,
      _normalizedVersionId(expectedVersionId),
    )) {
      final raw = box.get(key);
      if (raw is! Map) {
        continue;
      }

      if (!_matchesExpectedVersion(raw['version'], expectedVersionId)) {
        continue;
      }

      final filePath = raw['filePath']?.toString();
      if (filePath == null || filePath.isEmpty) {
        continue;
      }

      if (filePath.startsWith('assets/')) {
        return filePath;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        await box.delete(key);
        continue;
      }

      return file.path;
    }
    return null;
  }

  Future<DateTime?> getAudioDownloadedAt({
    required String languageCode,
    required String passageId,
    int? expectedVersionId,
  }) async {
    final box = await _box();
    for (final key in _audioLookupKeys(
      languageCode,
      passageId,
      _normalizedVersionId(expectedVersionId),
    )) {
      final raw = box.get(key);
      if (raw is! Map) {
        continue;
      }

      if (!_matchesExpectedVersion(raw['version'], expectedVersionId)) {
        continue;
      }

      return DateTime.tryParse(raw['downloadedAt']?.toString() ?? '');
    }
    return null;
  }

  Future<String> downloadAudio({
    required String languageCode,
    required String passageId,
    required String audioUrl,
    required ResolvedBibleVersion version,
  }) async {
    final uri = Uri.parse(audioUrl);
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Audio download failed with status ${response.statusCode}',
        uri: uri,
      );
    }

    final directory = await _audioDirectory(languageCode);
    await directory.create(recursive: true);

    final extension = _audioExtension(uri);
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_safePassageId(passageId)}$extension',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);

    final box = await _box();
    await box.put(
      _audioKey(languageCode, passageId),
      <String, dynamic>{
        'languageCode': languageCode,
        'passageId': passageId,
        'version': version.toJson(),
        'audioUrl': audioUrl,
        'filePath': file.path,
        'downloadedAt': DateTime.now().toIso8601String(),
      },
    );
    await box.put(
      _audioKey(
        languageCode,
        passageId,
        versionId: version.id,
      ),
      <String, dynamic>{
        'languageCode': languageCode,
        'passageId': passageId,
        'version': version.toJson(),
        'audioUrl': audioUrl,
        'filePath': file.path,
        'downloadedAt': DateTime.now().toIso8601String(),
      },
    );

    return file.path;
  }

  Future<void> saveBundledAudio({
    required String languageCode,
    required String passageId,
    required String assetPath,
    required ResolvedBibleVersion version,
  }) async {
    final box = await _box();
    await box.put(
      _audioKey(languageCode, passageId),
      <String, dynamic>{
        'languageCode': languageCode,
        'passageId': passageId,
        'version': version.toJson(),
        'audioUrl': assetPath,
        'filePath': assetPath,
        'downloadedAt': DateTime.now().toIso8601String(),
      },
    );
    await box.put(
      _audioKey(
        languageCode,
        passageId,
        versionId: version.id,
      ),
      <String, dynamic>{
        'languageCode': languageCode,
        'passageId': passageId,
        'version': version.toJson(),
        'audioUrl': assetPath,
        'filePath': assetPath,
        'downloadedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<OfflineLanguageStatus> getStatus({
    required String languageCode,
    String? passageId,
    int? expectedVersionId,
  }) async {
    final catalog = await getCatalog(
      languageCode,
      versionId: expectedVersionId,
    );
    if (passageId == null || passageId.isEmpty) {
      return OfflineLanguageStatus(
        hasCatalog: catalog != null,
        hasCurrentText: false,
        hasCurrentAudio: false,
      );
    }

    final chapterDownloadedAt = await getChapterDownloadedAt(
      languageCode: languageCode,
      passageId: passageId,
      expectedVersionId: expectedVersionId,
    );
    final audioPath = await getAudioFilePath(
      languageCode: languageCode,
      passageId: passageId,
      expectedVersionId: expectedVersionId,
    );
    final audioDownloadedAt = await getAudioDownloadedAt(
      languageCode: languageCode,
      passageId: passageId,
      expectedVersionId: expectedVersionId,
    );

    return OfflineLanguageStatus(
      hasCatalog: catalog != null,
      hasCurrentText: chapterDownloadedAt != null,
      hasCurrentAudio: audioPath != null,
      audioPath: audioPath,
      chapterCachedAt: chapterDownloadedAt,
      audioCachedAt: audioDownloadedAt,
    );
  }

  Future<void> clearLanguageData(String languageCode) async {
    final code = languageCode.toLowerCase();
    final box = await _box();

    final keysToDelete = box.keys
        .where((key) =>
            key is String &&
            (key.startsWith('catalog:$code') ||
             key.startsWith('chapter:$code:') ||
             key.startsWith('audio:$code:') ||
             key.startsWith('language_complete:$code')))
        .toList();
    await box.deleteAll(keysToDelete);

    final audioDir = await _audioDirectory(code);
    if (await audioDir.exists()) {
      await audioDir.delete(recursive: true);
    }
  }

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<dynamic>(_boxName);
    }
    return Hive.openBox<dynamic>(_boxName);
  }

  Future<Directory> _audioDirectory(String languageCode) async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(
      '${root.path}${Platform.pathSeparator}offline_bible${Platform.pathSeparator}audio${Platform.pathSeparator}$languageCode',
    );
  }

  String _catalogKey(
    String languageCode, {
    int? versionId,
  }) => versionId == null
      ? 'catalog:${languageCode.toLowerCase()}'
      : 'catalog:${languageCode.toLowerCase()}:v$versionId';

  Iterable<String> _catalogLookupKeys(String languageCode, int? versionId) sync* {
    if (versionId != null) {
      yield _catalogKey(languageCode, versionId: versionId);
    }
    yield _catalogKey(languageCode);
  }

  String _chapterKey(
    String languageCode,
    String passageId, {
    int? versionId,
  }) => versionId == null
      ? 'chapter:${languageCode.toLowerCase()}:${passageId.toUpperCase()}'
      : 'chapter:${languageCode.toLowerCase()}:v$versionId:${passageId.toUpperCase()}';

  Iterable<String> _chapterLookupKeys(
    String languageCode,
    String passageId,
    int? versionId,
  ) sync* {
    if (versionId != null) {
      yield _chapterKey(languageCode, passageId, versionId: versionId);
    }
    yield _chapterKey(languageCode, passageId);
  }

  String _audioKey(
    String languageCode,
    String passageId, {
    int? versionId,
  }) => versionId == null
      ? 'audio:${languageCode.toLowerCase()}:${passageId.toUpperCase()}'
      : 'audio:${languageCode.toLowerCase()}:v$versionId:${passageId.toUpperCase()}';

  Iterable<String> _audioLookupKeys(
    String languageCode,
    String passageId,
    int? versionId,
  ) sync* {
    if (versionId != null) {
      yield _audioKey(languageCode, passageId, versionId: versionId);
    }
    yield _audioKey(languageCode, passageId);
  }

  String _languageCompleteKey(
    String languageCode, {
    int? versionId,
  }) => versionId == null
      ? 'language_complete:${languageCode.toLowerCase()}'
      : 'language_complete:${languageCode.toLowerCase()}:v$versionId';

  Iterable<String> _languageCompleteLookupKeys(
    String languageCode,
    int? versionId,
  ) sync* {
    if (versionId != null) {
      yield _languageCompleteKey(languageCode, versionId: versionId);
    }
    yield _languageCompleteKey(languageCode);
  }

  String _safePassageId(String passageId) =>
      passageId.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

  String _audioExtension(Uri uri) {
    final normalizedPath = uri.path.toLowerCase();
    if (normalizedPath.endsWith('.mp3')) {
      return '.mp3';
    }
    if (normalizedPath.endsWith('.m4a')) {
      return '.m4a';
    }
    if (normalizedPath.endsWith('.aac')) {
      return '.aac';
    }
    return '.mp3';
  }

  bool _matchesExpectedVersion(dynamic rawVersion, int? expectedVersionId) {
    if (expectedVersionId == null || expectedVersionId <= 0) {
      return true;
    }

    if (rawVersion is! Map) {
      return false;
    }

    final map = Map<String, dynamic>.from(rawVersion);
    final storedVersionId = map['id'] is int
        ? map['id'] as int
        : int.tryParse(map['id']?.toString() ?? '');
    return storedVersionId == expectedVersionId;
  }

  int? _normalizedVersionId(int? versionId) {
    if (versionId == null || versionId <= 0) {
      return null;
    }
    return versionId;
  }
}
