class BibleChapter {
  const BibleChapter({
    required this.id,
    required this.passageId,
    required this.title,
    required this.verseCount,
    required this.audioUrl,
    required this.audio,
  });

  final String id;
  final String passageId;
  final String title;
  final int verseCount;
  final String? audioUrl;
  final Map<String, dynamic>? audio;

  factory BibleChapter.fromJson(Map<String, dynamic> json) {
    final audioMap = _asMap(json['audio']);
    final audioUrl = _extractAudioUrl(json) ?? _extractAudioUrl(audioMap ?? {});

    return BibleChapter(
      id: _asString(json['id']) ?? '',
      passageId: _asString(json['passage_id']) ?? '',
      title: _asString(json['title']) ?? '',
      verseCount:
          (json['verses'] is List) ? (json['verses'] as List).length : 0,
      audioUrl: audioUrl,
      audio: audioMap,
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _asString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String? _extractAudioUrl(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return null;
  }

  if (value is List) {
    for (final dynamic item in value) {
      final extracted = _extractAudioUrl(item);
      if (extracted != null) {
        return extracted;
      }
    }
    return null;
  }

  if (value is Map) {
    final normalized = Map<String, dynamic>.from(value);
    final preferredKeys = <String>[
      'audio_url',
      'audioUrl',
      'url',
      'stream_url',
      'streamUrl',
      'path',
      'src',
    ];

    for (final key in preferredKeys) {
      final extracted = _extractAudioUrl(normalized[key]);
      if (extracted != null) {
        return extracted;
      }
    }

    for (final dynamic nested in normalized.values) {
      final extracted = _extractAudioUrl(nested);
      if (extracted != null) {
        return extracted;
      }
    }
  }

  return null;
}
