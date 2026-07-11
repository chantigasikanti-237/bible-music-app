import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv._();

  static Future<void> load() async {
    await dotenv.load(fileName: 'assets/env/.env', isOptional: true);
  }

  static String get apiBaseUrl => _value(
        dartDefineValue: const String.fromEnvironment('API_BASE_URL'),
        dotenvKey: 'API_BASE_URL',
      );

  static String get apiBaseUrlWeb => _value(
        dartDefineValue: const String.fromEnvironment('API_BASE_URL_WEB'),
        dotenvKey: 'API_BASE_URL_WEB',
      );

  static String get apiBaseUrlAndroid => _value(
        dartDefineValue: const String.fromEnvironment('API_BASE_URL_ANDROID'),
        dotenvKey: 'API_BASE_URL_ANDROID',
      );

  static String _value({
    required String dartDefineValue,
    required String dotenvKey,
  }) {
    final normalizedDartDefine = dartDefineValue.trim();
    if (normalizedDartDefine.isNotEmpty) {
      return normalizedDartDefine;
    }

    try {
      return dotenv.maybeGet(dotenvKey)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }
}
