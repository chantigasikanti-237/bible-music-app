import 'api_client.dart';

class VerseService {
  VerseService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> saveVerse({
    required int bibleId,
    required String passageId,
    required int verseNumber,
    required String text,
  }) async {
    final response = await _apiClient.post(
      '/api/verses/save',
      requiresAuth: true,
      body: {
        'bibleId': bibleId,
        'passageId': passageId,
        'verseNumber': verseNumber,
        'text': text,
      },
    );

    if (response['success'] == false) {
      throw ApiException(
          response['message']?.toString() ?? 'Failed to save verse');
    }

    final data = response['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getSavedVerses() async {
    final response = await _apiClient.get(
      '/api/verses',
      requiresAuth: true,
    );

    if (response['success'] == false) {
      throw ApiException(
          response['message']?.toString() ?? 'Failed to load saved verses');
    }

    final data = response['data'];
    if (data is! List) {
      return const [];
    }

    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<void> deleteSavedVerse(String id) async {
    final response = await _apiClient.delete(
      '/api/verses/$id',
      requiresAuth: true,
    );

    if (response['success'] == false) {
      throw ApiException(
          response['message']?.toString() ?? 'Failed to delete saved verse');
    }
  }
}
