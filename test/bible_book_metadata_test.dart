import 'package:bible_app/config/bible_book_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical book metadata returns native titles for supported languages',
      () {
    final genesis = bibleBookMetadataForId('GEN');
    final revelation = bibleBookMetadataForId('REV');

    expect(genesis, isNotNull);
    expect(revelation, isNotNull);

    expect(genesis!.titleForLanguage('hi'), 'उत्पत्ति');
    expect(genesis.titleForLanguage('ta'), 'ஆதியாகமம்');
    expect(genesis.titleForLanguage('kn'), 'ಆದಿಕಾಂಡ');
    expect(genesis.titleForLanguage('ml'), 'ഉല്പത്തി');
    expect(genesis.titleForLanguage('mr'), 'उत्पत्ति');
    expect(revelation!.titleForLanguage('ml'), 'വെളിപ്പാട്');
  });
}
