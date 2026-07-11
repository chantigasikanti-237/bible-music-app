import 'dart:convert';

import 'package:bible_app/services/api_client.dart';
import 'package:bible_app/services/auth_service.dart';
import 'package:bible_app/services/verse_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('shared ApiClient propagates auth token to verse calls', () async {
    final capturedRequests = <http.Request>[];

    final mockClient = MockClient((request) async {
      capturedRequests.add(request);

      if (request.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({'success': true, 'token': 'test-bearer-token'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/save')) {
        return http.Response(
          jsonEncode({'success': true, 'data': <String, dynamic>{}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      // DELETE /api/verses/:id
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = ApiClient(httpClient: mockClient);
    final authService = AuthService(apiClient: apiClient);
    final verseService = VerseService(apiClient: apiClient);

    await authService.login('user@example.com', 'password123');

    await verseService.saveVerse(
      bibleId: 1,
      passageId: 'GEN.1.1',
      verseNumber: 1,
      text: 'In the beginning God created the heavens and the earth.',
    );

    await verseService.deleteSavedVerse('verse-abc');

    expect(capturedRequests, hasLength(3));

    final loginRequest = capturedRequests[0];
    final saveRequest = capturedRequests[1];
    final deleteRequest = capturedRequests[2];

    expect(
      loginRequest.headers.containsKey('Authorization'),
      isFalse,
      reason: 'Login must not send an Authorization header',
    );

    expect(
      saveRequest.headers['Authorization'],
      equals('Bearer test-bearer-token'),
      reason: 'saveVerse must send Authorization: Bearer <token>',
    );

    expect(
      deleteRequest.headers['Authorization'],
      equals('Bearer test-bearer-token'),
      reason: 'deleteSavedVerse must send Authorization: Bearer <token>',
    );
  });
}
