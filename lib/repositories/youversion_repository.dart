import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_version.dart';
import '../services/youversion_api_service.dart';

abstract class YouVersionRepository {
  Future<List<BibleVersion>> getBibleVersions({
    String languageCode,
    bool audioOnly,
  });

  Future<List<BibleBook>> getBooksForBible({
    required int bibleId,
  });

  Future<List<BibleChapter>> getChaptersForBook({
    required int bibleId,
    required String bookId,
  });

  Future<String?> getChapterAudioUrl({
    required int bibleId,
    required String passageId,
    String? languageCode,
  });

  Future<ChapterAudioResolution?> getChapterAudioResolution({
    required int bibleId,
    required String passageId,
    String? languageCode,
  });
}

class YouVersionRepositoryImpl implements YouVersionRepository {
  YouVersionRepositoryImpl(this._apiService);

  final YouVersionApiService _apiService;

  @override
  Future<List<BibleVersion>> getBibleVersions({
    String languageCode = 'en',
    bool audioOnly = false,
  }) {
    return _apiService.fetchBibleVersions(
      languageCode: languageCode,
      audioOnly: audioOnly,
    );
  }

  @override
  Future<List<BibleBook>> getBooksForBible({
    required int bibleId,
  }) {
    return _apiService.fetchBooks(bibleId: bibleId);
  }

  @override
  Future<List<BibleChapter>> getChaptersForBook({
    required int bibleId,
    required String bookId,
  }) {
    return _apiService.fetchChapters(
      bibleId: bibleId,
      bookId: bookId,
    );
  }

  @override
  Future<String?> getChapterAudioUrl({
    required int bibleId,
    required String passageId,
    String? languageCode,
  }) async {
    final resolution = await getChapterAudioResolution(
      bibleId: bibleId,
      passageId: passageId,
      languageCode: languageCode,
    );
    return resolution?.audioUrl;
  }

  @override
  Future<ChapterAudioResolution?> getChapterAudioResolution({
    required int bibleId,
    required String passageId,
    String? languageCode,
  }) {
    return _apiService.fetchChapterAudioResolution(
      bibleId: bibleId,
      passageId: passageId,
      languageCode: languageCode,
    );
  }
}
