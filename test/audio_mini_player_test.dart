import 'dart:async';

import 'package:bible_app/controllers/app_audio_player_controller.dart';
import 'package:bible_app/models/audio_track.dart';
import 'package:bible_app/widgets/audio_mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AudioMiniPlayer stays hidden while idle',
      (WidgetTester tester) async {
    final controller = _FakeAudioMiniPlayerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioMiniPlayer(controller: controller),
        ),
      ),
    );

    expect(find.text('Telugu Worship'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('AudioMiniPlayer shows track metadata and details tap',
      (WidgetTester tester) async {
    final controller = _FakeAudioMiniPlayerController();
    addTearDown(controller.dispose);
    var detailsTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioMiniPlayer(
            controller: controller,
            onTapPlayerDetails: () {
              detailsTapCount += 1;
            },
          ),
        ),
      ),
    );

    controller.emit(
      const AppAudioPlayerState(
        status: AppAudioPlaybackStatus.paused,
        track: _testTrack,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(find.text('Telugu Worship'), findsOneWidget);
    expect(find.text('Grace Channel'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);

    await tester.tap(find.text('Telugu Worship'));
    await tester.pump();

    expect(detailsTapCount, 1);
  });

  testWidgets('AudioMiniPlayer toggles playback action button',
      (WidgetTester tester) async {
    final controller = _FakeAudioMiniPlayerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioMiniPlayer(controller: controller),
        ),
      ),
    );

    controller.emit(
      const AppAudioPlayerState(
        status: AppAudioPlaybackStatus.playing,
        track: _testTrack,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(controller.pauseCount, 1);

    controller.emit(
      const AppAudioPlayerState(
        status: AppAudioPlaybackStatus.paused,
        track: _testTrack,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    expect(controller.playedTracks, <String>['video-1']);
  });

  testWidgets('AudioMiniPlayer shows compact loading indicator',
      (WidgetTester tester) async {
    final controller = _FakeAudioMiniPlayerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioMiniPlayer(controller: controller),
        ),
      ),
    );

    controller.emit(
      const AppAudioPlayerState(
        status: AppAudioPlaybackStatus.loading,
        track: _testTrack,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Play'), findsNothing);
    expect(find.byTooltip('Pause'), findsNothing);
  });

  testWidgets('AudioMiniPlayer opens full player controls by default',
      (WidgetTester tester) async {
    final controller = _FakeAudioMiniPlayerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioMiniPlayer(controller: controller),
        ),
      ),
    );

    controller.emit(
      const AppAudioPlayerState(
        status: AppAudioPlaybackStatus.paused,
        track: _testTrack,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    await tester.tap(find.text('Telugu Worship').first);
    await tester.pumpAndSettle();
    controller.emitPosition(const Duration(seconds: 12));
    controller.emitDuration(const Duration(minutes: 3, seconds: 4));
    await tester.pump();

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.byTooltip('Back 10 seconds'), findsOneWidget);
    expect(find.byTooltip('Forward 10 seconds'), findsOneWidget);
    expect(find.byTooltip('Stop'), findsWidgets);
    expect(find.byType(Slider), findsOneWidget);
  });
}

const AudioTrack _testTrack = AudioTrack(
  id: 'video-1',
  title: 'Telugu Worship',
  thumbnailUrl: '',
  channelTitle: 'Grace Channel',
);

class _FakeAudioMiniPlayerController implements AudioMiniPlayerController {
  final StreamController<AppAudioPlayerState> _stateController =
      StreamController<AppAudioPlayerState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();

  @override
  AppAudioPlayerState currentState = const AppAudioPlayerState.idle();

  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;
  final List<Duration> seekPositions = <Duration>[];
  final List<String> playedTracks = <String>[];

  @override
  Stream<AppAudioPlayerState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  void emit(AppAudioPlayerState state) {
    currentState = state;
    _stateController.add(state);
  }

  void emitPosition(Duration position) {
    _positionController.add(position);
  }

  void emitDuration(Duration? duration) {
    _durationController.add(duration);
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
  }

  @override
  Future<void> resume() async {
    resumeCount += 1;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> playTrack(AudioTrack track) async {
    playedTracks.add(track.id);
  }

  Future<void> dispose() async {
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }
}
