import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message';
}

class ApiClient {
  static String get baseUrl => ApiConfig.baseUrl;

  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String? _token;

  Future<dynamic> getRequest(String endpoint) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$endpoint'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        _errorMessageForResponse(response, fallbackAction: 'load data'),
        statusCode: response.statusCode,
      );
    }
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = false,
  }) async {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (requiresAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await _httpClient.get(uri, headers: headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeResponseBody(response);
    } else {
      throw ApiException(
        _errorMessageForResponse(response, fallbackAction: 'load data'),
        statusCode: response.statusCode,
      );
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (requiresAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeResponseBody(response);
    } else {
      throw ApiException(
        _errorMessageForResponse(response, fallbackAction: 'post data'),
        statusCode: response.statusCode,
      );
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (requiresAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final response = await _httpClient.delete(uri, headers: headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeResponseBody(response);
    } else {
      throw ApiException(
        _errorMessageForResponse(response, fallbackAction: 'delete data'),
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> saveToken(String token) async {
    _token = token;
  }

  Future<void> clearToken() async {
    _token = null;
  }

  dynamic _decodeResponseBody(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(response.body);
  }

  String _errorMessageForResponse(
    http.Response response, {
    required String fallbackAction,
  }) {
    final fallback = 'Failed to $fallbackAction: ${response.statusCode}';
    if (response.body.isEmpty) {
      return fallback;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final details = decoded['details'];
        if (details is Map<String, dynamic>) {
          final errors = details['errors'];
          if (errors is List && errors.isNotEmpty) {
            final firstError = errors.first;
            if (firstError is Map<String, dynamic>) {
              final message = firstError['message']?.toString().trim();
              if (message != null && message.isNotEmpty) {
                return message;
              }
            }
          }
        }

        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      return fallback;
    }

    return fallback;
  }
}
