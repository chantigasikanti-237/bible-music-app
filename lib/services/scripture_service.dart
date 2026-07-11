import 'dart:async';

import '../models/chapter_response.dart';
import 'api_client.dart';

class ScriptureService {
  ScriptureService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<ChapterResponse> fetchChapter(int bibleId, String passageId) async {
    final normalizedPassageId = passageId.trim();
    if (normalizedPassageId.isEmpty) {
      throw const ApiException('Passage ID is required');
    }

    Map<String, dynamic> responseJson;
    try {
      responseJson = await _apiClient.get(
        '/api/scripture/chapter',
        queryParameters: <String, String>{
          'bibleId': bibleId.toString(),
          'passageId': normalizedPassageId,
        },
      ).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ApiException('Chapter request timed out');
    }

    return ChapterResponse.fromJson(
      responseJson,
      fallbackBibleId: bibleId,
      fallbackPassageId: normalizedPassageId,
    );
  }
}
