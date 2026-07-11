import 'bible_languages.dart';

class SupportedLanguage {
  const SupportedLanguage({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

final List<SupportedLanguage> supportedLanguages = bibleLanguageOptions
    .map(
      (BibleLanguageOption option) => SupportedLanguage(
        code: option.code,
        label: option.nativeLabel,
      ),
    )
    .toList(growable: false);

final Set<String> supportedLanguageCodes = supportedLanguages
    .map((SupportedLanguage language) => language.code)
    .toSet();
