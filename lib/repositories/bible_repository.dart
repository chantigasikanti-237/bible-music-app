import '../config/api_config.dart';
import '../models/chapter_response.dart';
import '../services/scripture_service.dart';

class BibleRepository {
  BibleRepository(this.scriptureService);

  final ScriptureService scriptureService;

  static const Map<String, String> _localizedBookCodes = <String, String>{
    '\u0c06\u0c26\u0c3f\u0c15\u0c3e\u0c02\u0c21\u0c2e\u0c41': 'GEN',
    '\u0c28\u0c3f\u0c30\u0c4d\u0c17\u0c2e\u0c28\u0c2e\u0c41': 'EXO',
  };

  static const Map<String, String> _bookCodeByName = <String, String>{
    'GENESIS': 'GEN',
    'GEN': 'GEN',
    'EXODUS': 'EXO',
    'EXO': 'EXO',
    'LEVITICUS': 'LEV',
    'LEV': 'LEV',
    'NUMBERS': 'NUM',
    'NUM': 'NUM',
    'DEUTERONOMY': 'DEU',
    'DEU': 'DEU',
    'JOSHUA': 'JOS',
    'JOS': 'JOS',
    'JUDGES': 'JDG',
    'JDG': 'JDG',
    'RUTH': 'RUT',
    'RUT': 'RUT',
    '1SAMUEL': '1SA',
    'ISAMUEL': '1SA',
    'FIRSTSAMUEL': '1SA',
    '1SA': '1SA',
    '2SAMUEL': '2SA',
    'IISAMUEL': '2SA',
    'SECONDSAMUEL': '2SA',
    '2SA': '2SA',
    '1KINGS': '1KI',
    'IKINGS': '1KI',
    'FIRSTKINGS': '1KI',
    '1KI': '1KI',
    '2KINGS': '2KI',
    'IIKINGS': '2KI',
    'SECONDKINGS': '2KI',
    '2KI': '2KI',
    '1CHRONICLES': '1CH',
    'ICHRONICLES': '1CH',
    'FIRSTCHRONICLES': '1CH',
    '1CH': '1CH',
    '2CHRONICLES': '2CH',
    'IICHRONICLES': '2CH',
    'SECONDCHRONICLES': '2CH',
    '2CH': '2CH',
    'EZRA': 'EZR',
    'EZR': 'EZR',
    'NEHEMIAH': 'NEH',
    'NEH': 'NEH',
    'ESTHER': 'EST',
    'EST': 'EST',
    'JOB': 'JOB',
    'PSALM': 'PSA',
    'PSALMS': 'PSA',
    'PSA': 'PSA',
    'PROVERBS': 'PRO',
    'PRO': 'PRO',
    'ECCLESIASTES': 'ECC',
    'ECC': 'ECC',
    'SONGOFSONGS': 'SNG',
    'SONGOFSOLOMON': 'SNG',
    'CANTICLES': 'SNG',
    'SNG': 'SNG',
    'ISAIAH': 'ISA',
    'ISA': 'ISA',
    'JEREMIAH': 'JER',
    'JER': 'JER',
    'LAMENTATIONS': 'LAM',
    'LAM': 'LAM',
    'EZEKIEL': 'EZK',
    'EZK': 'EZK',
    'DANIEL': 'DAN',
    'DAN': 'DAN',
    'HOSEA': 'HOS',
    'HOS': 'HOS',
    'JOEL': 'JOL',
    'JOL': 'JOL',
    'AMOS': 'AMO',
    'AMO': 'AMO',
    'OBADIAH': 'OBA',
    'OBA': 'OBA',
    'JONAH': 'JON',
    'JON': 'JON',
    'MICAH': 'MIC',
    'MIC': 'MIC',
    'NAHUM': 'NAM',
    'NAM': 'NAM',
    'HABAKKUK': 'HAB',
    'HAB': 'HAB',
    'ZEPHANIAH': 'ZEP',
    'ZEP': 'ZEP',
    'HAGGAI': 'HAG',
    'HAG': 'HAG',
    'ZECHARIAH': 'ZEC',
    'ZEC': 'ZEC',
    'MALACHI': 'MAL',
    'MAL': 'MAL',
    'MATTHEW': 'MAT',
    'MAT': 'MAT',
    'MARK': 'MRK',
    'MRK': 'MRK',
    'LUKE': 'LUK',
    'LUK': 'LUK',
    'JOHN': 'JHN',
    'JHN': 'JHN',
    'ACTS': 'ACT',
    'ACT': 'ACT',
    'ROMANS': 'ROM',
    'ROM': 'ROM',
    '1CORINTHIANS': '1CO',
    'ICORINTHIANS': '1CO',
    'FIRSTCORINTHIANS': '1CO',
    '1CO': '1CO',
    '2CORINTHIANS': '2CO',
    'IICORINTHIANS': '2CO',
    'SECONDCORINTHIANS': '2CO',
    '2CO': '2CO',
    'GALATIANS': 'GAL',
    'GAL': 'GAL',
    'EPHESIANS': 'EPH',
    'EPH': 'EPH',
    'PHILIPPIANS': 'PHP',
    'PHP': 'PHP',
    'COLOSSIANS': 'COL',
    'COL': 'COL',
    '1THESSALONIANS': '1TH',
    'ITHESSALONIANS': '1TH',
    'FIRSTTHESSALONIANS': '1TH',
    '1TH': '1TH',
    '2THESSALONIANS': '2TH',
    'IITHESSALONIANS': '2TH',
    'SECONDTHESSALONIANS': '2TH',
    '2TH': '2TH',
    '1TIMOTHY': '1TI',
    'ITIMOTHY': '1TI',
    'FIRSTTIMOTHY': '1TI',
    '1TI': '1TI',
    '2TIMOTHY': '2TI',
    'IITIMOTHY': '2TI',
    'SECONDTIMOTHY': '2TI',
    '2TI': '2TI',
    'TITUS': 'TIT',
    'TIT': 'TIT',
    'PHILEMON': 'PHM',
    'PHM': 'PHM',
    'HEBREWS': 'HEB',
    'HEB': 'HEB',
    'JAMES': 'JAS',
    'JAS': 'JAS',
    '1PETER': '1PE',
    'IPETER': '1PE',
    'FIRSTPETER': '1PE',
    '1PE': '1PE',
    '2PETER': '2PE',
    'IIPETER': '2PE',
    'SECONDPETER': '2PE',
    '2PE': '2PE',
    '1JOHN': '1JN',
    'IJOHN': '1JN',
    'FIRSTJOHN': '1JN',
    '1JN': '1JN',
    '2JOHN': '2JN',
    'IIJOHN': '2JN',
    'SECONDJOHN': '2JN',
    '2JN': '2JN',
    '3JOHN': '3JN',
    'IIIJOHN': '3JN',
    'THIRDJOHN': '3JN',
    '3JN': '3JN',
    'JUDE': 'JUD',
    'JUD': 'JUD',
    'REVELATION': 'REV',
    'REV': 'REV',
  };

  Future<ChapterResponse> getChapter({
    required String language,
    required String book,
    required int chapter,
  }) async {
    final bibleId = ApiConfig.bibleIdForLanguage(language);
    final passageId = _buildPassageId(book, chapter);

    return scriptureService.fetchChapter(bibleId, passageId);
  }

  String _buildPassageId(String book, int chapter) {
    final localizedCode = _localizedBookCodes[book.trim()];
    if (localizedCode != null) {
      return '$localizedCode.$chapter';
    }

    final normalizedBook = _normalizeBookName(book);
    final mappedCode = _bookCodeByName[normalizedBook];
    if (mappedCode != null) {
      return '$mappedCode.$chapter';
    }

    final defaultCode = normalizedBook.length >= 3
        ? normalizedBook.substring(0, 3)
        : normalizedBook;
    return '$defaultCode.$chapter';
  }

  String _normalizeBookName(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
