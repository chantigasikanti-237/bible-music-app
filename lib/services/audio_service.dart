import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

enum _AudioInputType {
  network,
  asset,
  file,
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;
  MediaItem? _currentTag;

  Stream<bool> get playerStateStream => _player.playingStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  bool get isPlaying => _player.playing;

  Future<void> playSingle(
    String url, {
    String? title,
    String? artist,
    String? id,
    MediaItem? tag,
  }) async {
    await playUrl(url, title: title, artist: artist, id: id, tag: tag);
  }

  Future<void> playUrl(
    String url, {
    String? title,
    String? artist,
    String? id,
    MediaItem? tag,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw ArgumentError('Audio URL is required');
    }

    try {
      debugPrint('Loading audio URL: $normalizedUrl');
      if (_currentUrl != normalizedUrl || _currentTag != tag) {
        await _loadAudioSource(normalizedUrl, tag: tag);
        _currentUrl = normalizedUrl;
        _currentTag = tag;
        debugPrint('Audio loaded successfully: $normalizedUrl');
      } else {
        debugPrint('Audio already loaded, resuming: $normalizedUrl');
      }

      debugPrint('Starting playback...');
      await _player.play();
      debugPrint('Playback started');
    } catch (e) {
      debugPrint('Audio playback error: $e');
      rethrow;
    }
  }

  Future<void> _loadAudioSource(String source, {MediaItem? tag}) async {
    final sourceType = _detectInputType(source);
    switch (sourceType) {
      case _AudioInputType.asset:
        // just_audio_background requires a MediaItem tag on every AudioSource.
        final assetTag = tag ?? MediaItem(id: source, title: 'Bible Audio', artist: 'Bible App');
        await _player.setAudioSource(AudioSource.asset(source, tag: assetTag));
        break;
      case _AudioInputType.file:
        // just_audio_background requires a MediaItem tag on every AudioSource.
        final path = _normalizeFilePath(source);
        final fileTag = tag ?? MediaItem(id: source, title: 'Bible Audio', artist: 'Bible App');
        await _player.setAudioSource(
          AudioSource.uri(Uri.file(path), tag: fileTag),
        );
        break;
      case _AudioInputType.network:
        // just_audio_background requires a MediaItem tag on every AudioSource.
        // We provide a minimal tag so the assertion passes; the AudioCoordinator
        // still stops network Bible audio when the app is backgrounded.
        final networkTag = tag ?? MediaItem(id: source, title: 'Bible Audio', artist: 'Bible App');
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(source), tag: networkTag),
        );
        break;
    }
  }

  _AudioInputType _detectInputType(String source) {
    final normalized = source.trim().toLowerCase();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return _AudioInputType.network;
    }
    if (normalized.startsWith('assets/')) {
      return _AudioInputType.asset;
    }
    if (normalized.startsWith('file://')) {
      return _AudioInputType.file;
    }
    if (source.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(source)) {
      return _AudioInputType.file;
    }
    return _AudioInputType.network;
  }

  String _normalizeFilePath(String source) {
    if (source.startsWith('file://')) {
      return Uri.parse(source).toFilePath();
    }
    return source;
  }

  Future<void> togglePlayPause(
    String url, {
    String? title,
    String? artist,
    String? id,
    MediaItem? tag,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw ArgumentError('Audio URL is required');
    }

    if (_currentUrl == normalizedUrl && _player.playing) {
      await pause();
    } else {
      await playUrl(normalizedUrl, title: title, artist: artist, id: id, tag: tag);
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentUrl = null;
    _currentTag = null;
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }
}
