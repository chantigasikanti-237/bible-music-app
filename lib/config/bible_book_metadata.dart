import 'bible_book_titles.dart';

class BibleBookMetadata {
  const BibleBookMetadata({
    required this.id,
    required this.englishTitle,
    required this.teluguTitle,
    required this.chapterCount,
    required this.canon,
  });

  final String id;
  final String englishTitle;
  final String teluguTitle;
  final int chapterCount;
  final String canon;

  String titleForLanguage(String languageCode) {
    final normalizedLanguageCode = languageCode.trim().toLowerCase();
    final localizedTitle = localizedBibleBookTitles[normalizedLanguageCode]
            ?[id] ??
        (normalizedLanguageCode == 'te' ? teluguTitle : null);
    if (localizedTitle == null || localizedTitle.trim().isEmpty) {
      return englishTitle;
    }
    return _normalizeLocalizedTitle(localizedTitle);
  }

  String get audioSlug => englishTitle
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

const List<BibleBookMetadata> canonicalBibleBooks = <BibleBookMetadata>[
  BibleBookMetadata(
    id: 'GEN',
    englishTitle: 'Genesis',
    teluguTitle: 'ఆదికాండము',
    chapterCount: 50,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'EXO',
    englishTitle: 'Exodus',
    teluguTitle: 'నిర్గమకాండము',
    chapterCount: 40,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'LEV',
    englishTitle: 'Leviticus',
    teluguTitle: 'లేవీయకాండము',
    chapterCount: 27,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'NUM',
    englishTitle: 'Numbers',
    teluguTitle: 'సంఖ్యాకాండము',
    chapterCount: 36,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'DEU',
    englishTitle: 'Deuteronomy',
    teluguTitle: 'ద్వితీయోపదేశకాండము',
    chapterCount: 34,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'JOS',
    englishTitle: 'Joshua',
    teluguTitle: 'యెహోషువ',
    chapterCount: 24,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'JDG',
    englishTitle: 'Judges',
    teluguTitle: 'న్యాయాధిపతులు',
    chapterCount: 21,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'RUT',
    englishTitle: 'Ruth',
    teluguTitle: 'రూతు',
    chapterCount: 4,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: '1SA',
    englishTitle: '1 Samuel',
    teluguTitle: '1 సమూయేలు',
    chapterCount: 31,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: '2SA',
    englishTitle: '2 Samuel',
    teluguTitle: '2 సమూయేలు',
    chapterCount: 24,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: '1KI',
    englishTitle: '1 Kings',
    teluguTitle: '1 రాజులు',
    chapterCount: 22,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: '2KI',
    englishTitle: '2 Kings',
    teluguTitle: '2 రాజులు',
    chapterCount: 25,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: '1CH',
    englishTitle: '1 Chronicles',
    teluguTitle: '1 దినవృత్తాంతములు',
    chapterCount: 29,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: '2CH',
    englishTitle: '2 Chronicles',
    teluguTitle: '2 దినవృత్తాంతములు',
    chapterCount: 36,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'EZR',
    englishTitle: 'Ezra',
    teluguTitle: 'ఎజ్రా',
    chapterCount: 10,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'NEH',
    englishTitle: 'Nehemiah',
    teluguTitle: 'నెహెమ్యా',
    chapterCount: 13,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'EST',
    englishTitle: 'Esther',
    teluguTitle: 'ఎస్తేరు',
    chapterCount: 10,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'JOB',
    englishTitle: 'Job',
    teluguTitle: 'యోబు',
    chapterCount: 42,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'PSA',
    englishTitle: 'Psalms',
    teluguTitle: 'కీర్తనల గ్రంథము',
    chapterCount: 150,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'PRO',
    englishTitle: 'Proverbs',
    teluguTitle: 'సామెతలు',
    chapterCount: 31,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'ECC',
    englishTitle: 'Ecclesiastes',
    teluguTitle: 'ప్రసంగి',
    chapterCount: 12,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'SNG',
    englishTitle: 'Song of Songs',
    teluguTitle: 'పరమగీతము',
    chapterCount: 8,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'ISA',
    englishTitle: 'Isaiah',
    teluguTitle: 'యెషయా',
    chapterCount: 66,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'JER',
    englishTitle: 'Jeremiah',
    teluguTitle: 'యిర్మీయా',
    chapterCount: 52,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'LAM',
    englishTitle: 'Lamentations',
    teluguTitle: 'విలాపవాక్యములు',
    chapterCount: 5,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'EZK',
    englishTitle: 'Ezekiel',
    teluguTitle: 'యెహెజ్కేలు',
    chapterCount: 48,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'DAN',
    englishTitle: 'Daniel',
    teluguTitle: 'దానియేలు',
    chapterCount: 12,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'HOS',
    englishTitle: 'Hosea',
    teluguTitle: 'హోషేయ',
    chapterCount: 14,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'JOL',
    englishTitle: 'Joel',
    teluguTitle: 'యోవేలు',
    chapterCount: 3,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'AMO',
    englishTitle: 'Amos',
    teluguTitle: 'ఆమోసు',
    chapterCount: 9,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'OBA',
    englishTitle: 'Obadiah',
    teluguTitle: 'ఓబద్యా',
    chapterCount: 1,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'JON',
    englishTitle: 'Jonah',
    teluguTitle: 'యోనా',
    chapterCount: 4,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'MIC',
    englishTitle: 'Micah',
    teluguTitle: 'మీకా',
    chapterCount: 7,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'NAM',
    englishTitle: 'Nahum',
    teluguTitle: 'నహూము',
    chapterCount: 3,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'HAB',
    englishTitle: 'Habakkuk',
    teluguTitle: 'హబక్కూకు',
    chapterCount: 3,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'ZEP',
    englishTitle: 'Zephaniah',
    teluguTitle: 'జెఫన్యా',
    chapterCount: 3,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'HAG',
    englishTitle: 'Haggai',
    teluguTitle: 'హగ్గయి',
    chapterCount: 2,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'ZEC',
    englishTitle: 'Zechariah',
    teluguTitle: 'జెకర్యా',
    chapterCount: 14,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'MAL',
    englishTitle: 'Malachi',
    teluguTitle: 'మలాకీ',
    chapterCount: 4,
    canon: 'OT',
  ),
  BibleBookMetadata(
    id: 'MAT',
    englishTitle: 'Matthew',
    teluguTitle: 'మత్తయి',
    chapterCount: 28,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'MRK',
    englishTitle: 'Mark',
    teluguTitle: 'మార్కు',
    chapterCount: 16,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'LUK',
    englishTitle: 'Luke',
    teluguTitle: 'లూకా',
    chapterCount: 24,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'JHN',
    englishTitle: 'John',
    teluguTitle: 'యోహాను',
    chapterCount: 21,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'ACT',
    englishTitle: 'Acts',
    teluguTitle: 'అపొస్తలుల కార్యములు',
    chapterCount: 28,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'ROM',
    englishTitle: 'Romans',
    teluguTitle: 'రోమీయులకు',
    chapterCount: 16,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '1CO',
    englishTitle: '1 Corinthians',
    teluguTitle: '1 కొరింథీయులకు',
    chapterCount: 16,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '2CO',
    englishTitle: '2 Corinthians',
    teluguTitle: '2 కొరింథీయులకు',
    chapterCount: 13,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'GAL',
    englishTitle: 'Galatians',
    teluguTitle: 'గలతీయులకు',
    chapterCount: 6,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'EPH',
    englishTitle: 'Ephesians',
    teluguTitle: 'ఎఫెసీయులకు',
    chapterCount: 6,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'PHP',
    englishTitle: 'Philippians',
    teluguTitle: 'ఫిలిప్పీయులకు',
    chapterCount: 4,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'COL',
    englishTitle: 'Colossians',
    teluguTitle: 'కొలొస్సీయులకు',
    chapterCount: 4,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '1TH',
    englishTitle: '1 Thessalonians',
    teluguTitle: '1 థెస్సలొనీకయులకు',
    chapterCount: 5,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '2TH',
    englishTitle: '2 Thessalonians',
    teluguTitle: '2 థెస్సలొనీకయులకు',
    chapterCount: 3,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '1TI',
    englishTitle: '1 Timothy',
    teluguTitle: '1 తిమోతికి',
    chapterCount: 6,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '2TI',
    englishTitle: '2 Timothy',
    teluguTitle: '2 తిమోతికి',
    chapterCount: 4,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'TIT',
    englishTitle: 'Titus',
    teluguTitle: 'తీతుకు',
    chapterCount: 3,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'PHM',
    englishTitle: 'Philemon',
    teluguTitle: 'ఫిలేమోనుకు',
    chapterCount: 1,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'HEB',
    englishTitle: 'Hebrews',
    teluguTitle: 'హెబ్రీయులకు',
    chapterCount: 13,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'JAS',
    englishTitle: 'James',
    teluguTitle: 'యాకోబు',
    chapterCount: 5,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '1PE',
    englishTitle: '1 Peter',
    teluguTitle: '1 పేతురు',
    chapterCount: 5,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '2PE',
    englishTitle: '2 Peter',
    teluguTitle: '2 పేతురు',
    chapterCount: 3,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '1JN',
    englishTitle: '1 John',
    teluguTitle: '1 యోహాను',
    chapterCount: 5,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '2JN',
    englishTitle: '2 John',
    teluguTitle: '2 యోహాను',
    chapterCount: 1,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: '3JN',
    englishTitle: '3 John',
    teluguTitle: '3 యోహాను',
    chapterCount: 1,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'JUD',
    englishTitle: 'Jude',
    teluguTitle: 'యూదా',
    chapterCount: 1,
    canon: 'NT',
  ),
  BibleBookMetadata(
    id: 'REV',
    englishTitle: 'Revelation',
    teluguTitle: 'ప్రకటన గ్రంథము',
    chapterCount: 22,
    canon: 'NT',
  ),
];

final Map<String, BibleBookMetadata> canonicalBibleBookById =
    <String, BibleBookMetadata>{
  for (final BibleBookMetadata book in canonicalBibleBooks) book.id: book,
};

BibleBookMetadata? bibleBookMetadataForId(String bookId) {
  final normalizedBookId = bookId.trim().toUpperCase();
  if (normalizedBookId.isEmpty) {
    return null;
  }
  return canonicalBibleBookById[normalizedBookId];
}

String _normalizeLocalizedTitle(String value) {
  var normalized = value.replaceAll('\u00A0', ' ').trim();
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

  final slashIndex = normalized.indexOf(' / ');
  if (slashIndex > 0) {
    normalized = normalized.substring(0, slashIndex).trimRight();
  }

  if (normalized.endsWith(' 1') && RegExp(r'^[123] ').hasMatch(normalized)) {
    normalized = normalized.substring(0, normalized.length - 2).trimRight();
  }

  return normalized;
}
