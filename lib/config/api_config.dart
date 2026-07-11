import 'package:flutter/foundation.dart';
import 'app_env.dart';
import 'bible_languages.dart';

class ApiConfig {
  static String get baseUrl {
    final configuredBaseUrl = _configuredBaseUrl;
    if (configuredBaseUrl.isNotEmpty) {
      return _trimTrailingSlash(configuredBaseUrl);
    }

    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }

    return 'http://localhost:5000';
  }

  // Songs API
  static String get songsEndpoint => '$baseUrl/api/songs';
  static String get audioSongsEndpoint => '$baseUrl/api/audio/songs';

  static int bibleIdForLanguage(String language) {
    final option = bibleLanguageForCode(language);
    return option.fallbackBibleId ?? 111;
  }

  static String get _configuredBaseUrl {
    if (kIsWeb && AppEnv.apiBaseUrlWeb.isNotEmpty) {
      return AppEnv.apiBaseUrlWeb;
    }

    if (defaultTargetPlatform == TargetPlatform.android &&
        AppEnv.apiBaseUrlAndroid.isNotEmpty) {
      return AppEnv.apiBaseUrlAndroid;
    }

    return AppEnv.apiBaseUrl;
  }

  static String _trimTrailingSlash(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
