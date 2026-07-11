import 'package:bible_app/models/audio_track.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/widgets/audio_track_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'AudioTrackListView loads Telugu by default and switches language',
      (WidgetTester tester) async {
    final service = _FakeBibleService();
    AudioTrack? selectedTrack;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 420,
            child: AudioTrackListView(
              bibleService: service,
              onTrackSelected: (AudioTrack track) {
                selectedTrack = track;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(service.requestedLanguages, <String>['Telugu']);
    expect(find.text('Telugu Worship'), findsOneWidget);

    await tester.tap(find.text('Hindi'));
    await tester.pump();
    await tester.pump();

    expect(service.requestedLanguages, <String>['Telugu', 'Hindi']);
    expect(find.text('Hindi Worship'), findsOneWidget);

    await tester.tap(find.text('Hindi Worship'));
    await tester.pump();

    expect(selectedTrack?.id, 'hindi-video');
  });

  testWidgets('AudioTrackListView shows a compact empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: AudioTrackListView(
              bibleService:
                  _FakeBibleService(emptyLanguages: <String>{'Telugu'}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No tracks found in this language'), findsOneWidget);
    expect(find.text('Telugu'), findsWidgets);
  });
}

class _FakeBibleService extends BibleService {
  _FakeBibleService({this.emptyLanguages = const <String>{}});

  final Set<String> emptyLanguages;
  final List<String> requestedLanguages = <String>[];

  @override
  Future<List<AudioTrack>> fetchSongsByLanguage(String language) async {
    requestedLanguages.add(language);
    if (emptyLanguages.contains(language)) {
      return const <AudioTrack>[];
    }

    final normalized = language.toLowerCase();
    return <AudioTrack>[
      AudioTrack(
        id: '$normalized-video',
        title: '$language Worship',
        thumbnailUrl: '',
        channelTitle: '$language Channel',
      ),
    ];
  }
}
