import 'package:bible_app/config/bible_languages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requested Bible.com text and audio ids stay pinned per language', () {
    expect(bibleLanguageForCode('en').fallbackBibleId, 111);
    expect(bibleLanguageForCode('en').fallbackAudioBibleId, 111);

    expect(bibleLanguageForCode('te').fallbackBibleId, 1787);
    expect(bibleLanguageForCode('te').fallbackAudioBibleId, 1787);

    expect(bibleLanguageForCode('hi').fallbackBibleId, 1683);
    expect(bibleLanguageForCode('hi').fallbackAudioBibleId, 1683);

    expect(bibleLanguageForCode('ta').fallbackBibleId, 339);
    expect(bibleLanguageForCode('ta').fallbackAudioBibleId, 339);

    expect(bibleLanguageForCode('mr').fallbackBibleId, 1686);
    expect(bibleLanguageForCode('mr').fallbackAudioBibleId, 1686);

    expect(bibleLanguageForCode('ml').fallbackBibleId, 1693);
    expect(bibleLanguageForCode('ml').fallbackAudioBibleId, 1693);

    expect(bibleLanguageForCode('kn').fallbackBibleId, 1684);
    expect(bibleLanguageForCode('kn').fallbackAudioBibleId, 1898);
  });
}
