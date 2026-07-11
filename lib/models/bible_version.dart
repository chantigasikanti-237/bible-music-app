class BibleVersion {
  const BibleVersion({
    required this.id,
    required this.abbreviation,
    required this.title,
    required this.languageTag,
    required this.hasAudio,
    required this.audio,
    required this.books,
  });

  final int id;
  final String abbreviation;
  final String title;
  final String languageTag;
  final bool hasAudio;
  final Map<String, dynamic>? audio;
  final List<String> books;

  factory BibleVersion.fromJson(Map<String, dynamic> json) {
    final audioObject = _asMap(json['audio']);
    final hasAudio = _asBool(json['has_audio']) ??
        _asBool(json['hasAudio']) ??
        audioObject != null;

    return BibleVersion(
      id: _asInt(json['id']) ?? 0,
      abbreviation: _asString(json['abbreviation']) ?? '',
      title:
          _asString(json['localized_title']) ?? _asString(json['title']) ?? '',
      languageTag: _asString(json['language_tag']) ??
          _asString(json['languageTag']) ??
          '',
      hasAudio: hasAudio,
      audio: audioObject,
      books: _asStringList(json['books']),
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

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return null;
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((dynamic item) => item?.toString().trim() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}
