import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OfflineMusicService {
  OfflineMusicService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static const String _boxName = 'offline_songs';
  final http.Client _httpClient;

  Future<String?> getSongFilePath(String songId) async {
    final normalizedId = songId.trim();
    if (normalizedId.isEmpty) return null;

    final box = await _box();
    final raw = box.get(_songKey(normalizedId));
    if (raw is! Map) return null;

    final filePath = raw['filePath']?.toString();
    if (filePath == null || filePath.isEmpty) return null;

    final file = File(filePath);
    if (!await file.exists()) {
      await box.delete(_songKey(normalizedId));
      return null;
    }
    return file.path;
  }

  Future<String> saveSongAudio({
    required String songId,
    required String audioUrl,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(audioUrl);
    final request = http.Request('GET', uri);
    if (headers != null) request.headers.addAll(headers);

    final streamed = await _httpClient.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException(
        'Song audio download failed with status ${streamed.statusCode}',
        uri: uri,
      );
    }

    final directory = await _songsDirectory();
    await directory.create(recursive: true);

    final extension = _audioExtension(uri);
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${_safeId(songId)}$extension',
    );

    final sink = file.openWrite();
    try {
      await sink.addStream(streamed.stream);
    } finally {
      await sink.close();
    }

    final box = await _box();
    await box.put(
      _songKey(songId),
      <String, dynamic>{
        'songId': songId,
        'audioUrl': audioUrl,
        'filePath': file.path,
        'downloadedAt': DateTime.now().toIso8601String(),
      },
    );

    return file.path;
  }

  Future<void> deleteSongAudio(String songId) async {
    final normalizedId = songId.trim();
    if (normalizedId.isEmpty) return;

    final existingPath = await getSongFilePath(normalizedId);
    if (existingPath != null) {
      final file = File(existingPath);
      if (await file.exists()) await file.delete();
    }
    final box = await _box();
    await box.delete(_songKey(normalizedId));
  }

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  Future<Directory> _songsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(
      '${root.path}${Platform.pathSeparator}offline_songs'
      '${Platform.pathSeparator}audio',
    );
  }

  String _songKey(String songId) => 'song:${songId.trim()}';

  String _safeId(String songId) =>
      songId.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

  String _audioExtension(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m4a')) return '.m4a';
    if (path.endsWith('.aac')) return '.aac';
    if (path.endsWith('.ogg')) return '.ogg';
    if (path.endsWith('.opus')) return '.opus';
    return '.mp3';
  }
}
