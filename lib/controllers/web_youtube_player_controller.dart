import 'dart:async';

import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/audio_track.dart';
import 'app_audio_player_controller.dart';

/// Web-only audio controller backed by the YouTube IFrame Player API.
/// Used on Flutter web instead of [AppAudioPlayerController], because
/// server-side ytdl-core stream extraction is blocked by YouTube in browsers.
///
/// On Android/iOS, [AppAudioPlayerController] handles all playback via the
/// backend proxy — this class is never instantiated on those platforms.
class WebYouTubePlayerController implements AudioMiniPlayerController {
  WebYouTubePlayerController._() {
    _ytController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: false,
        loop: false,
        playsInline: true,
        enableCaption: false,
        strictRelatedVideos: true,
      ),
    );
    _ytSubscription = _ytController.listen(_onYtValue);
  }

  static final WebYouTubePlayerController instance =
      WebYouTubePlayerController._();

  late final YoutubePlayerController _ytController;
  late final StreamSubscription<YoutubePlayerValue> _ytSubscription; // held to cancel on dispose

  final StreamController<AppAudioPlayerState> _stateCtrl =
      StreamController<AppAudioPlayerState>.broadcast();
  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationCtrl =
      StreamController<Duration?>.broadcast();

  AudioTrack? _currentTrack;
  AppAudioPlayerState _currentState = const AppAudioPlayerState.idle();
  Timer? _positionTimer;

  YoutubePlayerController get ytController => _ytController;
  AudioTrack? get currentTrack => _currentTrack;

  @override
  AppAudioPlayerState get currentState => _currentState;

  @override
  Stream<AppAudioPlayerState> get stateStream => _stateCtrl.stream;

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  @override
  Future<void> playTrack(AudioTrack track) async {
    final videoId = track.id.trim();
    if (videoId.isEmpty) {
      _emitError('No YouTube video ID for this track.', track: track);
      return;
    }
    _currentTrack = track;
    _emit(AppAudioPlayerState(
      status: AppAudioPlaybackStatus.loading,
      track: track,
    ));

    // v6: loadVideoById queues the command internally until the IFrame player
    // is ready, so no onInit callback is needed.
    await _ytController.loadVideoById(videoId: videoId);
  }

  /// Pauses if [track] is the currently playing track; otherwise starts it.
  Future<void> toggleTrack(AudioTrack track) async {
    if (_currentTrack?.id.trim() == track.id.trim()) {
      if (_currentState.isPlaying) {
        await pause();
      } else {
        await resume();
      }
      return;
    }
    await playTrack(track);
  }

  @override
  Future<void> pause() => _ytController.pauseVideo();

  @override
  Future<void> resume() => _ytController.playVideo();

  @override
  Future<void> stop() async {
    await _ytController.stopVideo();
    _currentTrack = null;
    _stopPositionTimer();
    _positionCtrl.add(Duration.zero);
    _durationCtrl.add(null);
    _emit(const AppAudioPlayerState.idle());
  }

  @override
  Future<void> seek(Duration position) => _ytController.seekTo(
        seconds: position.inSeconds.toDouble(),
        allowSeekAhead: true,
      );

  // Queue / playback-mode — not supported on web; satisfy the interface contract.
  @override
  bool get hasQueue => false;
  @override
  PlaybackMode get playbackMode => PlaybackMode.none;
  @override
  Stream<PlaybackMode> get playbackModeStream => const Stream<PlaybackMode>.empty();
  @override
  Future<void> playNext() async {}
  @override
  Future<void> playPrevious() async {}
  @override
  void setPlaybackMode(PlaybackMode mode) {}

  void _onYtValue(YoutubePlayerValue v) {
    final track = _currentTrack;
    if (track == null) return;

    // Propagate duration whenever the IFrame metadata is populated.
    final dur = v.metaData.duration;
    if (dur > Duration.zero) _durationCtrl.add(dur);

    final AppAudioPlayerState next;
    switch (v.playerState) {
      case PlayerState.playing:
        next = AppAudioPlayerState(
          status: AppAudioPlaybackStatus.playing,
          track: track,
        );
        _startPositionTimer();
      case PlayerState.paused:
        next = AppAudioPlayerState(
          status: AppAudioPlaybackStatus.paused,
          track: track,
        );
        _stopPositionTimer();
      case PlayerState.buffering:
        next = AppAudioPlayerState(
          status: AppAudioPlaybackStatus.buffering,
          track: track,
        );
      case PlayerState.ended:
        next = AppAudioPlayerState(
          status: AppAudioPlaybackStatus.completed,
          track: track,
        );
        _stopPositionTimer();
      default:
        // unStarted / cued / unknown — stay in loading while IFrame warms up
        return;
    }

    _emit(next);
  }

  // youtube_player_iframe v3 exposes position only as Future<double> via
  // currentTime, not as a value-stream field. Poll every 500 ms while playing.
  void _startPositionTimer() {
    if (_positionTimer?.isActive ?? false) return;
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) async {
        try {
          final secs = await _ytController.currentTime;
          _positionCtrl.add(Duration(milliseconds: (secs * 1000).round()));
        } catch (_) {}
      },
    );
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _emitError(String message, {AudioTrack? track}) {
    _emit(AppAudioPlayerState(
      status: AppAudioPlaybackStatus.error,
      track: track ?? _currentTrack,
      errorMessage: message,
    ));
  }

  void _emit(AppAudioPlayerState state) {
    _currentState = state;
    if (!_stateCtrl.isClosed) _stateCtrl.add(state);
  }

  /// Releases resources. The singleton never calls this, but it keeps
  /// [_ytSubscription] referenced so the linter doesn't flag it as unused.
  void dispose() {
    _ytSubscription.cancel();
    _stopPositionTimer();
    _stateCtrl.close();
    _positionCtrl.close();
    _durationCtrl.close();
    _ytController.close();
  }
}
