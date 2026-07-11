import 'package:bible_app/models/audio_track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AudioTrack maps backend thumbnail field to thumbnailUrl', () {
    final track = AudioTrack.fromJson(const <String, dynamic>{
      'id': 'videoIdString',
      'title': 'Clean Video Title',
      'thumbnail': 'https://img.example/thumbnail.jpg',
      'channelTitle': 'Worship Leader Name',
      'publishedAt': '2026-05-24T00:00:00.000Z',
    });

    expect(track.id, 'videoIdString');
    expect(track.title, 'Clean Video Title');
    expect(track.thumbnailUrl, 'https://img.example/thumbnail.jpg');
    expect(track.channelTitle, 'Worship Leader Name');
    expect(track.audioUrl, isEmpty);
  });

  test('AudioTrack maps bundled file and artist fields', () {
    final track = AudioTrack.fromJson(const <String, dynamic>{
      'id': '1',
      'title': 'Genesis Chapter 1',
      'artist': 'Bible',
      'file': 'assets/audio/te/genesis_1.mp3',
    });

    expect(track.id, '1');
    expect(track.title, 'Genesis Chapter 1');
    expect(track.channelTitle, 'Bible');
    expect(track.audioUrl, 'assets/audio/te/genesis_1.mp3');
  });
}
