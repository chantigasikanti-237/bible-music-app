import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../config/api_config.dart';
import '../models/audio_track.dart';
import '../services/offline_music_service.dart';

enum AppAudioPlaybackStatus {
  idle,
  loading,
  buffering,
  playing,
  paused,
  completed,
  error,
}

enum PlaybackMode { none, loop, shuffle }

class AppAudioPlayerState {
  const AppAudioPlayerState({
    required this.status,
    this.track,
    this.errorMessage,
  });

  const AppAudioPlayerState.idle()
      : status = AppAudioPlaybackStatus.idle,
        track = null,
        errorMessage = null;

  final AppAudioPlaybackStatus status;
  final AudioTrack? track;
  final String? errorMessage;

  bool get isLoading =>
      status == AppAudioPlaybackStatus.loading ||
      status == AppAudioPlaybackStatus.buffering;

  bool get isPlaying => status == AppAudioPlaybackStatus.playing;
  bool get isPaused => status == AppAudioPlaybackStatus.paused;
  bool get hasError => status == AppAudioPlaybackStatus.error;
}

class AppAudioPlaybackException implements Exception {
  const AppAudioPlaybackException(this.message);

  final String message;

  @override
  String toString() => 'AppAudioPlaybackException: $message';
}

/// Shared interface implemented by both [AppAudioPlayerController] (mobile/desktop)
/// and [WebYouTubePlayerController] (web). Queue and playback-mode methods have
/// concrete no-op defaults so web-only and test controllers need not override them.
abstract class AudioMiniPlayerController {
  AppAudioPlayerState get currentState;
  Stream<AppAudioPlayerState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;

  Future<void> playTrack(AudioTrack track);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);

  // Queue controls — default no-ops for controllers that don't support a queue.
  bool get hasQueue => false;
  PlaybackMode get playbackMode => PlaybackMode.none;
  Stream<PlaybackMode> get playbackModeStream => const Stream<PlaybackMode>.empty();

  Future<void> playNext() async {}
  Future<void> playPrevious() async {}
  void setPlaybackMode(PlaybackMode mode) {}
}

class AppAudioPlayerController implements AudioMiniPlayerController {
  AppAudioPlayerController._({
    AudioPlayer? player,
    OfflineMusicService? offlineMusicService,
  })  : _player = player ?? AudioPlayer(),
        _offlineMusicService = offlineMusicService ?? OfflineMusicService() {
    _playerStateSubscription = _player.playerStateStream.listen(
      _handleNativePlayerState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Audio player state error: $error');
        _emitError('Audio playback failed.');
      },
    );
  }

  static final AppAudioPlayerController instance = AppAudioPlayerController._();
  static const Duration _streamResolveTimeout = Duration(seconds: 30);
  static const Duration _sourceLoadTimeout = Duration(seconds: 60);

  final AudioPlayer _player;
  final OfflineMusicService _offlineMusicService;
  final StreamController<AppAudioPlayerState> _stateController =
      StreamController<AppAudioPlayerState>.broadcast();
  final StreamController<PlaybackMode> _playbackModeController =
      StreamController<PlaybackMode>.broadcast();

  late final StreamSubscription<PlayerState> _playerStateSubscription;

  AudioTrack? _currentTrack;
  AppAudioPlayerState _currentState = const AppAudioPlayerState.idle();
  String? _currentRawAudioUrl;
  int _loadVersion = 0;
  bool _isResolvingStream = false;
  bool _isDisposed = false;

  // Queue state
  List<AudioTrack> _queue = const <AudioTrack>[];
  int _queueIndex = -1;
  PlaybackMode _playbackMode = PlaybackMode.none;
  final Random _random = Random();

  AudioPlayer get player => _player;
  AudioTrack? get currentTrack => _currentTrack;

  @override
  AppAudioPlayerState get currentState => _currentState;

  @override
  Stream<AppAudioPlayerState> get stateStream => _stateController.stream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  bool get hasQueue => _queue.isNotEmpty;
  List<AudioTrack> get queue => _queue;
  int get currentQueueIndex => _queueIndex;

  @override
  PlaybackMode get playbackMode => _playbackMode;

  @override
  Stream<PlaybackMode> get playbackModeStream => _playbackModeController.stream;

  bool get isPlaying => _player.playing;

  /// Sets the active playlist. The controller takes ownership of [tracks].
  /// [startIndex] is the index of the track that should play first.
  void setQueue(List<AudioTrack> tracks, {int startIndex = 0}) {
    _queue = List<AudioTrack>.unmodifiable(tracks);
    _queueIndex = tracks.isEmpty
        ? -1
        : startIndex.clamp(0, tracks.length - 1);
  }

  @override
  void setPlaybackMode(PlaybackMode mode) {
    _playbackMode = mode;
    _playbackModeController.add(mode);
  }

  @override
  Future<void> playNext() async {
    if (_queue.isEmpty) return;

    final int next;
    if (_playbackMode == PlaybackMode.shuffle) {
      next = _random.nextInt(_queue.length);
    } else {
      next = _queueIndex + 1;
      if (next >= _queue.length) {
        if (_playbackMode == PlaybackMode.loop) {
          _queueIndex = 0;
        }
        return;
      }
    }
    _queueIndex = next;
    await playTrack(_queue[_queueIndex]);
  }

  @override
  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    int prev = _queueIndex - 1;
    if (prev < 0) prev = _playbackMode == PlaybackMode.loop ? _queue.length - 1 : 0;
    _queueIndex = prev;
    await playTrack(_queue[_queueIndex]);
  }

  @override
  Future<void> playTrack(AudioTrack track) async {
    _assertNotDisposed();

    final trackKey = _trackKey(track);
    if (trackKey.isEmpty) {
      throw ArgumentError('AudioTrack.id or AudioTrack.audioUrl is required.');
    }

    if (_canResumeCurrentTrack(trackKey)) {
      await _player.play();
      return;
    }

    // Sync queue index to the track being played externally.
    final queuePos = _queue.indexWhere((t) => _trackKey(t) == trackKey);
    if (queuePos != -1) _queueIndex = queuePos;

    final loadVersion = ++_loadVersion;
    _currentTrack = track;
    _currentRawAudioUrl = null;
    _isResolvingStream = true;
    _emit(
      AppAudioPlayerState(
        status: AppAudioPlaybackStatus.loading,
        track: track,
      ),
    );

    String? resolvedUrl;
    try {
      resolvedUrl = await _resolveRawAudioUrl(track).timeout(
        _streamResolveTimeout,
        onTimeout: () => throw const AppAudioPlaybackException(
          'Audio stream took too long to prepare.',
        ),
      );
      if (_isStaleLoad(loadVersion)) return;

      _currentRawAudioUrl = resolvedUrl;
      await _player.stop();
      if (_isStaleLoad(loadVersion)) return;

      await _setResolvedAudioSource(track, resolvedUrl).timeout(
        _sourceLoadTimeout,
        onTimeout: () => throw const AppAudioPlaybackException(
          'Audio source took too long to load.',
        ),
      );
      if (_isStaleLoad(loadVersion)) return;

      _isResolvingStream = false;
      await _player.play();
      _emitFromPlayerState(_player.playerState);
    } catch (error, stackTrace) {
      if (_isStaleLoad(loadVersion)) return;
      debugPrint('Audio stream playback failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      // If the resolved URL was NOT the backend proxy (e.g. a youtube_explode_dart
      // URL that became IP-bound or expired), retry once with the backend proxy.
      final trackId = track.id.trim();
      final proxyUrl = trackId.isNotEmpty
          ? '${ApiConfig.baseUrl}/api/audio/stream/$trackId'
          : null;

      if (proxyUrl != null && resolvedUrl != proxyUrl) {
        debugPrint('[Audio] Retrying with backend proxy: $proxyUrl');
        try {
          _currentRawAudioUrl = proxyUrl;
          _isResolvingStream = true;
          await _player.stop();
          if (_isStaleLoad(loadVersion)) return;

          await _setResolvedAudioSource(track, proxyUrl).timeout(
            _sourceLoadTimeout,
            onTimeout: () => throw const AppAudioPlaybackException(
              'Audio source took too long to load.',
            ),
          );
          if (_isStaleLoad(loadVersion)) return;

          _isResolvingStream = false;
          await _player.play();
          _emitFromPlayerState(_player.playerState);
          return;
        } catch (retryErr) {
          if (_isStaleLoad(loadVersion)) return;
          debugPrint('[Audio] Backend proxy also failed: $retryErr');
        }
      }

      if (_isStaleLoad(loadVersion)) return;
      _currentRawAudioUrl = null;
      _isResolvingStream = false;
      await _player.stop();
      _emitError('Unable to play this track right now.', track: track);
    } finally {
      if (!_isStaleLoad(loadVersion)) {
        _isResolvingStream = false;
      }
    }
  }

  Future<void> toggleTrack(AudioTrack track) async {
    _assertNotDisposed();

    final trackKey = _trackKey(track);
    if (_trackKey(_currentTrack) == trackKey &&
        _player.playing &&
        !_isResolvingStream) {
      await pause();
      return;
    }

    await playTrack(track);
  }

  @override
  Future<void> pause() async {
    _assertNotDisposed();
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    _assertNotDisposed();
    await _player.play();
  }

  @override
  Future<void> stop() async {
    _assertNotDisposed();
    ++_loadVersion;
    _isResolvingStream = false;
    _currentTrack = null;
    _currentRawAudioUrl = null;
    await _player.stop();
    _emit(const AppAudioPlayerState.idle());
  }

  @override
  Future<void> seek(Duration position) async {
    _assertNotDisposed();
    await _player.seek(position);
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    ++_loadVersion;
    _isResolvingStream = false;
    await _playerStateSubscription.cancel();
    await _player.stop();
    await _player.dispose();
    await _stateController.close();
    await _playbackModeController.close();
  }

  /// Resolves the raw audio URL for [track].
  ///
  /// Priority:
  /// 1. Locally cached offline file (mobile only).
  /// 2. Explicit `audioUrl` on the track (bundled assets, pre-signed URLs).
  /// 3. Client-side YouTube stream extraction via youtube_explode_dart (mobile).
  /// 4. Backend stream proxy as final fallback.
  Future<String> _resolveRawAudioUrl(AudioTrack track) async {
    if (!kIsWeb) {
      final cachedPath =
          await _offlineMusicService.getSongFilePath(track.id.trim());
      if (cachedPath != null) return cachedPath;
    }

    final directAudioUrl = track.audioUrl.trim();
    if (directAudioUrl.isNotEmpty) return directAudioUrl;

    final trackId = track.id.trim();

    // On mobile, try youtube_explode_dart for direct stream URL extraction.
    // YouTube often blocks server-side proxy requests, so client-side resolution
    // is more reliable. Fall through to the backend proxy if this fails.
    // Stream through the backend proxy. The proxy uses yt-dlp to select an
    // audio-only format and pipes it; direct CDN URLs are IP-bound to the
    // server and fail when played from the device.
    return '${ApiConfig.baseUrl}/api/audio/stream/$trackId';
  }

  /// Downloads the audio for [track] to local storage.
  /// Tries youtube_explode_dart for a direct URL first, falls back to the
  /// backend proxy. Fire-and-forget — call without awaiting.
  Future<void> downloadTrackForOffline(AudioTrack track) async {
    if (kIsWeb) return;
    final trackId = track.id.trim();
    if (trackId.isEmpty) return;

    if (await _offlineMusicService.getSongFilePath(trackId) != null) return;

    final audioUrl = '${ApiConfig.baseUrl}/api/audio/stream/$trackId';

    try {
      await _offlineMusicService.saveSongAudio(
        songId: trackId,
        audioUrl: audioUrl,
      );
    } catch (err) {
      debugPrint(
        '[AppAudioPlayerController] downloadTrackForOffline failed for $trackId: $err',
      );
    }
  }

  Future<void> _setResolvedAudioSource(
    AudioTrack track,
    String audioSource,
  ) async {
    final mediaItem = _buildMediaItem(track, audioSource);
    if (_isBundledAssetAudioSource(audioSource)) {
      await _player.setAudioSource(
        AudioSource.asset(audioSource, tag: mediaItem),
      );
      return;
    }

    if (_isNetworkAudioSource(audioSource)) {
      final headers = _youtubeHeaders(audioSource);
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioSource),
          tag: mediaItem,
          headers: headers,
        ),
      );
      return;
    }

    await _player.setAudioSource(
      AudioSource.uri(Uri.file(audioSource), tag: mediaItem),
    );
  }

  MediaItem _buildMediaItem(AudioTrack track, String rawAudioUrl) {
    final thumbnailUrl = track.thumbnailUrl.trim();
    return MediaItem(
      id: track.id,
      title:
          track.title.trim().isEmpty ? 'Untitled worship track' : track.title,
      artist: track.channelTitle.trim().isEmpty
          ? 'Christian worship'
          : track.channelTitle,
      album: 'Bible App Worship',
      artUri: thumbnailUrl.isEmpty ? null : Uri.tryParse(thumbnailUrl),
      extras: <String, dynamic>{
        'rawAudioUrl': rawAudioUrl,
      },
    );
  }

  // iOS client URLs (googlevideo.com) have no strict User-Agent binding.
  // Sending the Android YouTube UA for iOS-signed URLs causes 403, so we let
  // ExoPlayer use its default headers instead.
  Map<String, String>? _youtubeHeaders(String url) => null;

  bool _isBundledAssetAudioSource(String value) {
    return value.trim().replaceAll('\\', '/').startsWith('assets/');
  }

  bool _isNetworkAudioSource(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _canResumeCurrentTrack(String trackKey) {
    return _trackKey(_currentTrack) == trackKey &&
        _currentRawAudioUrl != null &&
        !_isResolvingStream &&
        _player.processingState != ProcessingState.idle &&
        _player.processingState != ProcessingState.completed;
  }

  String _trackKey(AudioTrack? track) {
    if (track == null) return '';
    final directAudioUrl = track.audioUrl.trim();
    if (directAudioUrl.isNotEmpty) return directAudioUrl;
    return track.id.trim();
  }

  bool _isStaleLoad(int loadVersion) {
    return _isDisposed || loadVersion != _loadVersion;
  }

  void _handleNativePlayerState(PlayerState playerState) {
    if (_isResolvingStream) return;
    _emitFromPlayerState(playerState);

    // Auto-advance queue when a track completes.
    if (playerState.processingState == ProcessingState.completed) {
      if (_playbackMode == PlaybackMode.loop && _queue.isNotEmpty) {
        playTrack(_queue[_queueIndex]);
      } else {
        playNext();
      }
    }
  }

  void _emitFromPlayerState(PlayerState playerState) {
    final status = switch (playerState.processingState) {
      ProcessingState.idle => AppAudioPlaybackStatus.idle,
      ProcessingState.loading => AppAudioPlaybackStatus.buffering,
      ProcessingState.buffering => AppAudioPlaybackStatus.buffering,
      ProcessingState.ready => playerState.playing
          ? AppAudioPlaybackStatus.playing
          : AppAudioPlaybackStatus.paused,
      ProcessingState.completed => AppAudioPlaybackStatus.completed,
    };

    _emit(
      AppAudioPlayerState(
        status: status,
        track: _currentTrack,
      ),
    );
  }

  void _emitError(String message, {AudioTrack? track}) {
    _emit(
      AppAudioPlayerState(
        status: AppAudioPlaybackStatus.error,
        track: track ?? _currentTrack,
        errorMessage: message,
      ),
    );
  }

  void _emit(AppAudioPlayerState state) {
    if (_stateController.isClosed) return;
    _currentState = state;
    _stateController.add(state);
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('AppAudioPlayerController has been disposed.');
    }
  }
}
