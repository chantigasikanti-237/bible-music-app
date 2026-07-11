import '../models/hymn.dart';
import 'api_client.dart';

class HymnsService {
  HymnsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<HymnsPageResult> fetchSongs({
    required int page,
    int limit = 50,
    String? search,
    String? languageCode,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final normalizedSearch = search?.trim();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      queryParameters['search'] = normalizedSearch;
    }

    final normalizedLanguage = languageCode?.trim().toLowerCase();
    if (normalizedLanguage != null && normalizedLanguage.isNotEmpty) {
      queryParameters['language'] = normalizedLanguage;
    }

    final response = await _apiClient.get(
      '/api/songs',
      queryParameters: queryParameters,
    );

    final data = response['data'];
    final rawSongs = data is List ? data : const <dynamic>[];
    final songs = rawSongs
        .whereType<Map>()
        .map(
          (Map rawSong) => Hymn.fromJson(
            Map<String, dynamic>.from(rawSong),
          ),
        )
        .toList(growable: false);

    final pagination = response['pagination'] is Map
        ? Map<String, dynamic>.from(response['pagination'] as Map)
        : const <String, dynamic>{};

    return HymnsPageResult(
      songs: songs,
      page: _readInt(pagination['page']) ?? page,
      limit: _readInt(pagination['limit']) ?? limit,
      nextPage: _readInt(pagination['nextPage']),
      hasNextPage: pagination['hasNextPage'] is bool
          ? pagination['hasNextPage'] as bool
          : songs.length >= limit,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

class HymnsPageResult {
  const HymnsPageResult({
    required this.songs,
    required this.page,
    required this.limit,
    required this.nextPage,
    required this.hasNextPage,
  });

  final List<Hymn> songs;
  final int page;
  final int limit;
  final int? nextPage;
  final bool hasNextPage;
}
