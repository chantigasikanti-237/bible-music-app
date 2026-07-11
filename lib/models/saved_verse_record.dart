class BookmarkCollection {
  const BookmarkCollection({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  factory BookmarkCollection.fromJson(Map<String, dynamic> json) {
    return BookmarkCollection(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class SavedVerseRecord {
  const SavedVerseRecord({
    required this.id,
    required this.languageCode,
    required this.bibleId,
    required this.versionId,
    required this.versionLabel,
    required this.bookId,
    required this.bookTitle,
    required this.chapterNumber,
    required this.verseNumber,
    required this.passageId,
    required this.text,
    required this.savedAt,
    this.collectionId,
    this.remoteId,
  });

  final String id;
  final String languageCode;
  final int bibleId;
  final int versionId;
  final String versionLabel;
  final String bookId;
  final String bookTitle;
  final int chapterNumber;
  final int verseNumber;
  final String passageId;
  final String text;
  final DateTime savedAt;
  final String? collectionId;
  final String? remoteId;

  String get reference => '$bookTitle $chapterNumber:$verseNumber';

  SavedVerseRecord copyWith({
    String? id,
    String? languageCode,
    int? bibleId,
    int? versionId,
    String? versionLabel,
    String? bookId,
    String? bookTitle,
    int? chapterNumber,
    int? verseNumber,
    String? passageId,
    String? text,
    DateTime? savedAt,
    Object? collectionId = _unset,
    Object? remoteId = _unset,
  }) {
    return SavedVerseRecord(
      id: id ?? this.id,
      languageCode: languageCode ?? this.languageCode,
      bibleId: bibleId ?? this.bibleId,
      versionId: versionId ?? this.versionId,
      versionLabel: versionLabel ?? this.versionLabel,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      verseNumber: verseNumber ?? this.verseNumber,
      passageId: passageId ?? this.passageId,
      text: text ?? this.text,
      savedAt: savedAt ?? this.savedAt,
      collectionId: identical(collectionId, _unset)
          ? this.collectionId
          : collectionId as String?,
      remoteId:
          identical(remoteId, _unset) ? this.remoteId : remoteId as String?,
    );
  }

  factory SavedVerseRecord.fromJson(Map<String, dynamic> json) {
    return SavedVerseRecord(
      id: json['id']?.toString().trim() ?? '',
      languageCode: json['languageCode']?.toString().trim().toLowerCase() ?? '',
      bibleId: json['bibleId'] is int
          ? json['bibleId'] as int
          : int.tryParse(json['bibleId']?.toString() ?? '') ?? 0,
      versionId: json['versionId'] is int
          ? json['versionId'] as int
          : int.tryParse(json['versionId']?.toString() ?? '') ?? 0,
      versionLabel: json['versionLabel']?.toString().trim() ?? '',
      bookId: json['bookId']?.toString().trim().toUpperCase() ?? '',
      bookTitle: json['bookTitle']?.toString().trim() ?? '',
      chapterNumber: json['chapterNumber'] is int
          ? json['chapterNumber'] as int
          : int.tryParse(json['chapterNumber']?.toString() ?? '') ?? 0,
      verseNumber: json['verseNumber'] is int
          ? json['verseNumber'] as int
          : int.tryParse(json['verseNumber']?.toString() ?? '') ?? 0,
      passageId: json['passageId']?.toString().trim().toUpperCase() ?? '',
      text: json['text']?.toString().trim() ?? '',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      collectionId: _nullableString(json['collectionId']),
      remoteId: _nullableString(json['remoteId']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'languageCode': languageCode,
      'bibleId': bibleId,
      'versionId': versionId,
      'versionLabel': versionLabel,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'chapterNumber': chapterNumber,
      'verseNumber': verseNumber,
      'passageId': passageId,
      'text': text,
      'savedAt': savedAt.toIso8601String(),
      'collectionId': collectionId,
      'remoteId': remoteId,
    };
  }
}

String? _nullableString(dynamic value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

const Object _unset = Object();
