import 'dart:convert';

import 'package:bible_app/services/bible_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchSongsByLanguage requests dynamic audio endpoint and maps tracks',
      () async {
    Uri? requestedUri;
    final service = BibleService(
      baseUrl: 'http://localhost:5000/',
      httpClient: MockClient((http.Request request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode(const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'telugu-video-1',
              'title': 'Telugu Worship',
              'thumbnail': 'https://img.example/telugu.jpg',
              'channelTitle': 'Worship Channel',
              'publishedAt': '2026-05-24T00:00:00.000Z',
            },
          ]),
          200,
        );
      }),
    );

    final tracks = await service.fetchSongsByLanguage('Telugu Worship');

    expect(
      requestedUri.toString(),
      'http://localhost:5000/api/audio/songs/Telugu%20Worship',
    );
    expect(tracks, hasLength(1));
    expect(tracks.single.id, 'telugu-video-1');
    expect(tracks.single.thumbnailUrl, 'https://img.example/telugu.jpg');
    expect(tracks.single.channelTitle, 'Worship Channel');
  });

  test('fetchSongsByLanguage keeps bundled tracks before remote Telugu results',
      () async {
    final service = BibleService(
      baseUrl: 'http://localhost:5000',
      httpClient: MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'telugu-video-1',
              'title': 'Remote Telugu Worship',
              'thumbnail': 'https://img.example/telugu.jpg',
              'channelTitle': 'Worship Channel',
            },
          ]),
          200,
        );
      }),
    );

    final tracks = await service.fetchSongsByLanguage('Telugu');

    expect(tracks, hasLength(greaterThan(1)));
    expect(tracks.first.title, 'Genesis Chapter 1');
    expect(tracks.first.audioUrl, 'assets/audio/te/genesis_1.mp3');
    expect(tracks.last.id, 'telugu-video-1');
  });

  test('fetchSongsByLanguage returns an empty list on server failure',
      () async {
    final service = BibleService(
      baseUrl: 'http://localhost:5000',
      httpClient: MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      ),
    );

    final tracks = await service.fetchSongsByLanguage('Hindi');

    expect(tracks, isEmpty);
  });

  test('fetchSongsByLanguage falls back to bundled Telugu audio assets',
      () async {
    final service = BibleService(
      baseUrl: 'http://localhost:5000',
      httpClient: MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      ),
    );

    final tracks = await service.fetchSongsByLanguage('Telugu');

    expect(tracks, isNotEmpty);
    expect(tracks.first.title, 'Genesis Chapter 1');
    expect(tracks.first.channelTitle, 'Bible');
    expect(tracks.first.audioUrl, 'assets/audio/te/genesis_1.mp3');
  });
}
