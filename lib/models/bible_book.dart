class BibleBook {
  const BibleBook({
    required this.id,
    required this.title,
    required this.fullTitle,
    required this.abbreviation,
    required this.canon,
    required this.chapterCount,
  });

  final String id;
  final String title;
  final String fullTitle;
  final String abbreviation;
  final String canon;
  final int chapterCount;

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    final chapters = json['chapters'];
    final chapterCount = json['chapterCount'] is int
        ? json['chapterCount'] as int
        : chapters is List
            ? chapters.length
            : 0;

    return BibleBook(
      id: _asString(json['id']) ?? '',
      title: _asString(json['title']) ?? '',
      fullTitle:
          _asString(json['full_title']) ?? _asString(json['title']) ?? '',
      abbreviation: _asString(json['abbreviation']) ?? '',
      canon: _asString(json['canon']) ?? '',
      chapterCount: chapterCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'full_title': fullTitle,
      'abbreviation': abbreviation,
      'canon': canon,
      'chapterCount': chapterCount,
    };
  }
}

String? _asString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
