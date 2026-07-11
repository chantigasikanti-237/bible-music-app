import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/audio_track.dart';
import '../models/chapter_response.dart';

class BibleService {
  BibleService({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = _trimTrailingSlash(baseUrl ?? ApiConfig.baseUrl);

  static const Duration _audioRequestTimeout = Duration(seconds: 30);

  final http.Client _httpClient;
  final String _baseUrl;

  String resolveLocalDataLanguage(String language) {
    final normalizedLanguage = language.trim().toLowerCase();
    switch (normalizedLanguage) {
      case 'te':
        return 'te';
      case 'hi':
      case 'en':
      default:
        return 'en';
    }
  }

  Future<List<AudioTrack>> searchSongs(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const <AudioTrack>[];
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/audio/search?q=${Uri.encodeComponent(q)}',
      );
      final response = await _httpClient.get(uri).timeout(_audioRequestTimeout);
      if (response.statusCode != 200) return const <AudioTrack>[];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const <AudioTrack>[];
      return _parseAudioTracks(decoded);
    } catch (_) {
      return const <AudioTrack>[];
    }
  }

  Future<List<AudioTrack>> fetchSongsByLanguage(String language) async {
    final normalizedLanguage = language.trim();
    if (normalizedLanguage.isEmpty) {
      return const <AudioTrack>[];
    }

    // Fetch from backend — network/timeout errors fall back to bundled tracks.
    http.Response? response;
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/audio/songs/${Uri.encodeComponent(normalizedLanguage)}',
      );
      response = await _httpClient.get(uri).timeout(_audioRequestTimeout);
    } on TimeoutException catch (error) {
      debugPrint('fetchSongsByLanguage timed out: $error');
      return _loadBundledSongsByLanguage(normalizedLanguage);
    } catch (error) {
      debugPrint('fetchSongsByLanguage failed: $error');
      return _loadBundledSongsByLanguage(normalizedLanguage);
    }

    // 429 — quota exceeded; try bundled fallback before surfacing error to UI.
    if (response.statusCode == 429) {
      final bundled = await _loadBundledSongsByLanguage(normalizedLanguage);
      if (bundled.isNotEmpty) return bundled;
      throw Exception(
        'Worship songs are temporarily unavailable — '
        'the YouTube content limit resets daily. Try again tomorrow.',
      );
    }

    if (response.statusCode != 200) {
      debugPrint(
        'fetchSongsByLanguage failed with status '
        '${response.statusCode}: ${response.body}',
      );
      return _loadBundledSongsByLanguage(normalizedLanguage);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      debugPrint(
        'fetchSongsByLanguage expected a JSON array but received '
        '${decoded.runtimeType}.',
      );
      return _loadBundledSongsByLanguage(normalizedLanguage);
    }

    return _withBundledTracksFirst(
      normalizedLanguage,
      _parseAudioTracks(decoded),
    );
  }

  Future<List<AudioTrack>> _loadBundledSongsByLanguage(String language) async {
    try {
      final localData = await rootBundle.loadString('lib/data/songs.json');
      final decoded = jsonDecode(localData);
      if (decoded is! List) {
        return const <AudioTrack>[];
      }

      final requestedLanguageCode = _audioLanguageCodeFor(language);
      return _parseAudioTracks(decoded)
          .where(
            (AudioTrack track) =>
                _audioLanguageCodeForTrack(track) == requestedLanguageCode,
          )
          .toList(growable: false);
    } catch (error) {
      debugPrint('loadBundledSongsByLanguage failed: $error');
      return const <AudioTrack>[];
    }
  }

  Future<List<AudioTrack>> _withBundledTracksFirst(
    String language,
    List<AudioTrack> remoteTracks,
  ) async {
    final bundledTracks = await _loadBundledSongsByLanguage(language);
    if (bundledTracks.isEmpty) {
      return remoteTracks;
    }
    if (remoteTracks.isEmpty) {
      return bundledTracks;
    }

    final bundledKeys = bundledTracks.map(_audioTrackKey).toSet();
    final uniqueRemoteTracks = remoteTracks
        .where(
            (AudioTrack track) => !bundledKeys.contains(_audioTrackKey(track)))
        .toList(growable: false);

    return <AudioTrack>[...bundledTracks, ...uniqueRemoteTracks];
  }

  List<AudioTrack> _parseAudioTracks(List<dynamic> decoded) {
    return decoded
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) => AudioTrack.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((AudioTrack track) => track.id.isNotEmpty)
        .toList(growable: false);
  }

  String _audioLanguageCodeFor(String language) {
    switch (language.trim().toLowerCase()) {
      case 'telugu':
      case 'te':
        return 'te';
      case 'hindi':
      case 'hi':
        return 'hi';
      case 'tamil':
      case 'ta':
        return 'ta';
      case 'malayalam':
      case 'ml':
        return 'ml';
      case 'kannada':
      case 'kn':
        return 'kn';
      case 'english':
      case 'en':
        return 'en';
      default:
        return language.trim().toLowerCase();
    }
  }

  String _audioLanguageCodeForTrack(AudioTrack track) {
    // Explicit language tag takes priority (used in bundled songs.json entries).
    if (track.language.isNotEmpty) {
      return _audioLanguageCodeFor(track.language);
    }

    final audioUrl = track.audioUrl.trim().replaceAll('\\', '/');
    final match = RegExp(r'(?:^|/)audio/([^/]+)/').firstMatch(audioUrl);
    if (match != null) {
      return _audioLanguageCodeFor(match.group(1) ?? '');
    }

    return '';
  }

  String _audioTrackKey(AudioTrack track) {
    final audioUrl = track.audioUrl.trim();
    if (audioUrl.isNotEmpty) {
      return audioUrl;
    }

    return track.id.trim();
  }

  Future<List<Book>> getBible(String language) async {
    final box = Hive.box('bible_cache');
    final resolvedLanguage = resolveLocalDataLanguage(language);

    // Read from local cache first so the sample library opens immediately.
    final cached = box.get(resolvedLanguage);
    final cachedBooks = _parseBiblePayload(cached);
    if (cachedBooks.isNotEmpty) {
      return cachedBooks;
    }

    try {
      final localData = await rootBundle.loadString(
        _resolveBibleAssetPath(resolvedLanguage),
      );

      final decoded = _normalizeDecoded(jsonDecode(localData));
      final books = _parseBiblePayload(decoded);
      if (books.isNotEmpty) {
        box.put(
          resolvedLanguage,
          books.map((Book book) => book.toJson()).toList(growable: false),
        );
      }

      return books;
    } catch (_) {}

    return const <Book>[];
  }

  List<Book> _parseBiblePayload(dynamic payload) {
    if (payload is Map) {
      final mapPayload = Map<String, dynamic>.from(payload);
      return mapPayload.entries
          .map<Book>(
            (entry) => Book.fromBibleEntry(entry.key, entry.value),
          )
          .where((Book book) => book.name.isNotEmpty)
          .toList(growable: false);
    }

    if (payload is List) {
      return payload
          .whereType<Map>()
          .map<Map<String, dynamic>>(Map<String, dynamic>.from)
          .map<Book>(Book.fromJson)
          .where((Book book) => book.name.isNotEmpty)
          .toList(growable: false);
    }

    return const <Book>[];
  }

  dynamic _normalizeDecoded(dynamic value) {
    if (value is Map) {
      final mapValue = Map<String, dynamic>.from(value);
      return mapValue.map<String, dynamic>(
        (String key, dynamic nestedValue) =>
            MapEntry<String, dynamic>(key, _normalizeDecoded(nestedValue)),
      );
    }

    if (value is List) {
      return value.map<dynamic>(_normalizeDecoded).toList(growable: false);
    }

    return value;
  }

  String _resolveBibleAssetPath(String resolvedLanguageCode) {
    switch (resolvedLanguageCode) {
      case 'te':
        return 'lib/data/te.json';
      case 'hi':
      case 'en':
      default:
        return 'lib/data/en.json';
    }
  }

  static String _trimTrailingSlash(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
