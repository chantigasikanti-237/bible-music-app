import 'dart:async';

import 'package:flutter/widgets.dart';

import '../controllers/app_audio_player_controller.dart';
import 'audio_service.dart' as bible_audio;

/// Enforces three rules across the two independent audio sources:
///
/// 1. **Mutual exclusivity** — only one source plays at a time.
/// 2. **Stop Bible audio when leaving the Bible tab** — tab-change events are
///    forwarded here by [AppShellController.selectTab].
/// 3. **Background / lock-screen gating for Bible audio** — streamed Bible
///    audio is stopped when the app goes to background; locally stored
///    (downloaded or bundled) audio is allowed to continue.
///
/// This is a singleton that lives for the lifetime of the app.
class AudioCoordinator with WidgetsBindingObserver {
  AudioCoordinator._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AudioCoordinator instance = AudioCoordinator._();

  // AppShellController.bibleIndex == 1. Duplicated here to avoid a circular
  // import (app_shell_controller → audio_coordinator → app_shell_controller).
  static const int _bibleTabIndex = 1;

  final bible_audio.AudioService _biblePlayer = bible_audio.AudioService();
  final AppAudioPlayerController _songsPlayer = AppAudioPlayerController.instance;

  String? _currentBibleAudioSource;

  // ---------------------------------------------------------------------------
  // Public helpers
  // ---------------------------------------------------------------------------

  /// Returns true when [source] refers to local storage (bundled asset or
  /// user-downloaded file) rather than a network stream.
  static bool isLocalAudioSource(String source) {
    final s = source.trim();
    return s.startsWith('assets/') ||
        s.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(s);
  }

  // ---------------------------------------------------------------------------
  // Claim methods — call before starting playback
  // ---------------------------------------------------------------------------

  /// Must be called before playing Bible chapter audio.
  /// Stops the worship-song player if it is active.
  Future<void> claimBible(String audioSource) async {
    _currentBibleAudioSource = audioSource;
    final songsState = _songsPlayer.currentState;
    if (songsState.isPlaying || songsState.isLoading) {
      await _songsPlayer.stop();
    }
  }

  /// Must be called before playing a worship song.
  /// Stops Bible chapter audio if it is active.
  Future<void> claimSong() async {
    if (_biblePlayer.isPlaying) {
      await _biblePlayer.stop();
      _currentBibleAudioSource = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Tab-change hook — called by AppShellController
  // ---------------------------------------------------------------------------

  /// Invoked by [AppShellController.selectTab] on every tab transition.
  /// Stops Bible audio whenever the user navigates away from the Bible tab.
  void onTabChanging(int fromIndex, int toIndex) {
    if (fromIndex == _bibleTabIndex && toIndex != _bibleTabIndex) {
      unawaited(_stopBibleAudio());
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _biblePlayer.isPlaying &&
        !_bibleAudioIsLocal) {
      // Streamed Bible audio must not continue when the app is backgrounded.
      unawaited(_stopBibleAudio());
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  bool get _bibleAudioIsLocal {
    final src = _currentBibleAudioSource;
    return src != null && isLocalAudioSource(src);
  }

  Future<void> _stopBibleAudio() async {
    if (_biblePlayer.isPlaying) {
      await _biblePlayer.stop();
    }
    _currentBibleAudioSource = null;
  }
}
