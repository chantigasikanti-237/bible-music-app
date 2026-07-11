import 'api_client.dart';

class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    required this.message,
  });

  final String message;
}

class AuthService {
  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> register(String name, String email, String password) async {
    final response = await _apiClient.post(
      '/api/auth/register',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      },
    );

    if (response['success'] == false) {
      throw ApiException(
          response['message']?.toString() ?? 'Registration failed');
    }
  }

  Future<String> login(String email, String password) async {
    final response = await _apiClient.post(
      '/api/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    if (response['success'] == false) {
      throw ApiException(response['message']?.toString() ?? 'Login failed');
    }

    final token = response['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const ApiException('Login response did not include a token');
    }

    await _apiClient.saveToken(token);
    return token;
  }

  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    final response = await _apiClient.post(
      '/api/auth/password-reset/request',
      body: {
        'email': email.trim(),
      },
    );

    if (response['success'] == false) {
      throw ApiException(
        response['message']?.toString() ?? 'Password reset request failed',
      );
    }

    return PasswordResetRequestResult(
      message: response['message']?.toString() ??
          'If the account exists, password reset instructions will be sent.',
    );
  }

  Future<void> resetPassword({
    required String otpCode,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/password-reset/confirm',
      body: {
        'otpCode': otpCode.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );

    if (response['success'] == false) {
      throw ApiException(
        response['message']?.toString() ?? 'Password reset failed',
      );
    }
  }

  Future<void> logout() {
    return _apiClient.clearToken();
  }
}
