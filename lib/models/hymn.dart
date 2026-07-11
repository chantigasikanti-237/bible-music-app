class Hymn {
  const Hymn({
    required this.id,
    required this.songId,
    required this.title,
    required this.languageCode,
    required this.lyricsSections,
    required this.tags,
    required this.isPublished,
  });

  factory Hymn.fromJson(Map<String, dynamic> json) {
    final rawId = _readString(json['_id']) ??
        _readString(json['id']) ??
        _readString(json['songId']) ??
        _readString(json['slug']) ??
        _readString(json['title']) ??
        '';
    final songId = _readString(json['songId']) ?? rawId;

    return Hymn(
      id: rawId,
      songId: songId,
      title: _readString(json['title']) ?? 'Untitled hymn',
      languageCode: (_readString(json['languageCode']) ?? 'en').toLowerCase(),
      lyricsSections: _readLyricsSections(json['lyricsSections']),
      tags: _readStringList(json['tags']),
      isPublished:
          json['isPublished'] is bool ? json['isPublished'] as bool : true,
    );
  }

  final String id;
  final String songId;
  final String title;
  final String languageCode;
  final List<HymnLyricsSection> lyricsSections;
  final List<String> tags;
  final bool isPublished;

  static String? _readString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! Iterable) {
      return const <String>[];
    }
    return value
        .map<String?>(_readString)
        .whereType<String>()
        .toList(growable: false);
  }

  static List<HymnLyricsSection> _readLyricsSections(dynamic value) {
    if (value is! Iterable) {
      return const <HymnLyricsSection>[];
    }
    return value
        .whereType<Map>()
        .map(
          (Map section) => HymnLyricsSection.fromJson(
            Map<String, dynamic>.from(section),
          ),
        )
        .where((HymnLyricsSection section) => section.text.isNotEmpty)
        .toList(growable: false);
  }
}

class HymnLyricsSection {
  const HymnLyricsSection({
    required this.label,
    required this.text,
  });

  factory HymnLyricsSection.fromJson(Map<String, dynamic> json) {
    return HymnLyricsSection(
      label: Hymn._readString(json['label']),
      text: Hymn._readString(json['text']) ?? '',
    );
  }

  final String? label;
  final String text;
}
