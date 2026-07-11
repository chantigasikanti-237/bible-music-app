import 'dart:convert';

import 'package:bible_app/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('post surfaces backend error messages', () async {
    final apiClient = ApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'An account with that email already exists',
          }),
          409,
        ),
      ),
    );

    await expectLater(
      apiClient.post('/api/auth/register', body: const {}),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.message,
              'message',
              'An account with that email already exists',
            )
            .having((error) => error.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('post prefers validation detail messages', () async {
    final apiClient = ApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Validation failed',
            'details': {
              'errors': [
                {'field': 'password', 'message': 'Password is too short'},
              ],
            },
          }),
          400,
        ),
      ),
    );

    await expectLater(
      apiClient.post('/api/auth/register', body: const {}),
      throwsA(
        isA<ApiException>()
            .having(
                (error) => error.message, 'message', 'Password is too short')
            .having((error) => error.statusCode, 'statusCode', 400),
      ),
    );
  });
}
