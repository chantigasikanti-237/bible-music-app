import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/saved_verse_record.dart';
import '../models/user_model.dart';

class UserService extends ChangeNotifier {
  static const String _userBox = 'user_box';
  late UserModel _user;
  static const double _minBibleReaderTextScale = 0.85;
  static const double _maxBibleReaderTextScale = 1.75;

  UserService({
    UserModel? initialUser,
    bool loadFromStorage = true,
  }) {
    _user = initialUser ?? UserModel();
    if (loadFromStorage) {
      _loadUser();
    }
  }

  UserModel get user => _user;

  Future<void> _loadUser() async {
    final box = await Hive.openBox(_userBox);
    final data = box.get('user');
    if (data != null && data is Map) {
      _user = UserModel(
        authStatus: AuthStatus.values[data['authStatus'] ?? 0],
        name: data['name'],
        email: data['email'],
        bibleLanguage: data['bibleLanguage'] ?? 'en',
        songsLanguage: data['songsLanguage'] ?? 'en',
        theme: AppTheme.values[data['theme'] ?? 0],
        bookmarkedVerses: List<String>.from(data['bookmarkedVerses'] ?? []),
        highlightedVerses: _readStringList(data['highlightedVerses']),
        favoriteSongs: List<String>.from(data['favoriteSongs'] ?? []),
        savedVerses: _readSavedVerses(data['savedVerses']),
        bookmarkCollections:
            _readBookmarkCollections(data['bookmarkCollections']),
        bibleVersionIdsByLanguage:
            _readIntMap(data['bibleVersionIdsByLanguage']),
        bibleAudioEnabledByLanguage:
            _readBoolMap(data['bibleAudioEnabledByLanguage']),
        bibleAudioProfileByLanguage:
            _readStringMap(data['bibleAudioProfileByLanguage']),
        bibleReaderTextScale:
            _readBibleReaderTextScale(data['bibleReaderTextScale']),
      );
      notifyListeners();
    }
  }

  Future<void> saveUser() async {
    final box = await Hive.openBox(_userBox);
    await box.put('user', {
      'authStatus': _user.authStatus.index,
      'name': _user.name,
      'email': _user.email,
      'bibleLanguage': _user.bibleLanguage,
      'songsLanguage': _user.songsLanguage,
      'theme': _user.theme.index,
      'bookmarkedVerses': _user.bookmarkedVerses,
      'highlightedVerses': _user.highlightedVerses,
      'favoriteSongs': _user.favoriteSongs,
      'savedVerses': _user.savedVerses
          .map((SavedVerseRecord verse) => verse.toJson())
          .toList(growable: false),
      'bookmarkCollections': _user.bookmarkCollections
          .map((BookmarkCollection collection) => collection.toJson())
          .toList(growable: false),
      'bibleVersionIdsByLanguage': _user.bibleVersionIdsByLanguage,
      'bibleAudioEnabledByLanguage': _user.bibleAudioEnabledByLanguage,
      'bibleAudioProfileByLanguage': _user.bibleAudioProfileByLanguage,
      'bibleReaderTextScale': _user.bibleReaderTextScale,
    });
  }

  void updateUser(UserModel user) {
    _user = user;
    saveUser();
    notifyListeners();
  }

  // Convenience methods for updating fields
  void setBibleLanguage(String lang) {
    updateUser(_user.copyWith(bibleLanguage: lang));
  }

  void setBibleVersionForLanguage(String languageCode, int versionId) {
    final normalizedLanguage = languageCode.trim().toLowerCase();
    if (normalizedLanguage.isEmpty || versionId <= 0) {
      return;
    }
    final updated = Map<String, int>.from(_user.bibleVersionIdsByLanguage)
      ..[normalizedLanguage] = versionId;
    updateUser(_user.copyWith(bibleVersionIdsByLanguage: updated));
  }

  void setBibleAudioEnabledForLanguage(String languageCode, bool enabled) {
    final normalizedLanguage = languageCode.trim().toLowerCase();
    if (normalizedLanguage.isEmpty) {
      return;
    }
    final updated = Map<String, bool>.from(_user.bibleAudioEnabledByLanguage)
      ..[normalizedLanguage] = enabled;
    updateUser(_user.copyWith(bibleAudioEnabledByLanguage: updated));
  }

  void setBibleAudioProfileForLanguage(String languageCode, String profileId) {
    final normalizedLanguage = languageCode.trim().toLowerCase();
    final normalizedProfile = profileId.trim();
    if (normalizedLanguage.isEmpty || normalizedProfile.isEmpty) {
      return;
    }
    final updated = Map<String, String>.from(_user.bibleAudioProfileByLanguage)
      ..[normalizedLanguage] = normalizedProfile;
    updateUser(_user.copyWith(bibleAudioProfileByLanguage: updated));
  }

  void setBibleReaderTextScale(double value) {
    final clamped = value.clamp(
      _minBibleReaderTextScale,
      _maxBibleReaderTextScale,
    );
    updateUser(_user.copyWith(bibleReaderTextScale: clamped));
  }

  void setSongsLanguage(String lang) {
    updateUser(_user.copyWith(songsLanguage: lang));
  }

  void setTheme(AppTheme theme) {
    updateUser(_user.copyWith(theme: theme));
  }

  SavedVerseRecord saveVerseRecord({
    required String languageCode,
    required int bibleId,
    required int versionId,
    required String versionLabel,
    required String bookId,
    required String bookTitle,
    required int chapterNumber,
    required int verseNumber,
    required String passageId,
    required String text,
  }) {
    final normalizedLanguage = languageCode.trim().toLowerCase();
    final normalizedBookId = bookId.trim().toUpperCase();
    final normalizedPassageId = passageId.trim().toUpperCase();
    final normalizedText = text.trim();
    if (normalizedLanguage.isEmpty ||
        normalizedBookId.isEmpty ||
        normalizedPassageId.isEmpty ||
        normalizedText.isEmpty ||
        chapterNumber <= 0 ||
        verseNumber <= 0) {
      throw ArgumentError('A complete verse reference is required.');
    }

    final recordId =
        '$normalizedLanguage:$versionId:$normalizedPassageId:$verseNumber';
    final existingIndex = _user.savedVerses.indexWhere(
      (SavedVerseRecord verse) => verse.id == recordId,
    );
    final existing =
        existingIndex == -1 ? null : _user.savedVerses[existingIndex];
    final nextRecord = (existing ??
            SavedVerseRecord(
              id: recordId,
              languageCode: normalizedLanguage,
              bibleId: bibleId,
              versionId: versionId,
              versionLabel: versionLabel.trim(),
              bookId: normalizedBookId,
              bookTitle: bookTitle.trim(),
              chapterNumber: chapterNumber,
              verseNumber: verseNumber,
              passageId: normalizedPassageId,
              text: normalizedText,
              savedAt: DateTime.now(),
            ))
        .copyWith(
      languageCode: normalizedLanguage,
      bibleId: bibleId,
      versionId: versionId,
      versionLabel: versionLabel.trim(),
      bookId: normalizedBookId,
      bookTitle: bookTitle.trim(),
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
      passageId: normalizedPassageId,
      text: normalizedText,
      savedAt: existing?.savedAt ?? DateTime.now(),
    );

    final updatedVerses = List<SavedVerseRecord>.from(_user.savedVerses);
    if (existingIndex == -1) {
      updatedVerses.insert(0, nextRecord);
    } else {
      updatedVerses[existingIndex] = nextRecord;
      if (existingIndex > 0) {
        updatedVerses
          ..removeAt(existingIndex)
          ..insert(0, nextRecord);
      }
    }

    final updatedBookmarks = <String>{
      ..._user.bookmarkedVerses,
      recordId,
    }.toList(growable: false);
    updateUser(
      _user.copyWith(
        bookmarkedVerses: updatedBookmarks,
        savedVerses: List<SavedVerseRecord>.unmodifiable(updatedVerses),
      ),
    );
    return nextRecord;
  }

  void setSavedVerseRemoteId(String verseId, String remoteId) {
    final normalizedVerseId = verseId.trim();
    final normalizedRemoteId = remoteId.trim();
    if (normalizedVerseId.isEmpty || normalizedRemoteId.isEmpty) {
      return;
    }

    final updatedVerses = _user.savedVerses
        .map(
          (SavedVerseRecord verse) => verse.id == normalizedVerseId
              ? verse.copyWith(remoteId: normalizedRemoteId)
              : verse,
        )
        .toList(growable: false);
    updateUser(_user.copyWith(savedVerses: updatedVerses));
  }

  BookmarkCollection createBookmarkCollection(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Folder name is required.');
    }

    final existing =
        _user.bookmarkCollections.cast<BookmarkCollection?>().firstWhere(
              (BookmarkCollection? collection) =>
                  collection != null &&
                  collection.name.toLowerCase() == normalizedName.toLowerCase(),
              orElse: () => null,
            );
    if (existing != null) {
      return existing;
    }

    final collection = BookmarkCollection(
      id: 'collection-${DateTime.now().microsecondsSinceEpoch}',
      name: normalizedName,
      createdAt: DateTime.now(),
    );
    final updatedCollections = <BookmarkCollection>[
      collection,
      ..._user.bookmarkCollections,
    ];
    updateUser(_user.copyWith(bookmarkCollections: updatedCollections));
    return collection;
  }

  void assignSavedVerseToCollection(String verseId, String? collectionId) {
    final normalizedVerseId = verseId.trim();
    final normalizedCollectionId = collectionId?.trim();
    if (normalizedVerseId.isEmpty) {
      return;
    }
    if (normalizedCollectionId != null &&
        normalizedCollectionId.isNotEmpty &&
        !_user.bookmarkCollections.any(
          (BookmarkCollection collection) =>
              collection.id == normalizedCollectionId,
        )) {
      throw ArgumentError('Folder not found.');
    }

    final updatedVerses = _user.savedVerses
        .map(
          (SavedVerseRecord verse) => verse.id == normalizedVerseId
              ? verse.copyWith(
                  collectionId: normalizedCollectionId == null ||
                          normalizedCollectionId.isEmpty
                      ? null
                      : normalizedCollectionId,
                )
              : verse,
        )
        .toList(growable: false);
    updateUser(_user.copyWith(savedVerses: updatedVerses));
  }

  void removeSavedVerse(String verseId) {
    final normalizedVerseId = verseId.trim();
    if (normalizedVerseId.isEmpty) {
      return;
    }
    final updatedVerses = _user.savedVerses
        .where((SavedVerseRecord verse) => verse.id != normalizedVerseId)
        .toList(growable: false);
    final updatedBookmarks = _user.bookmarkedVerses
        .where((String id) => id != normalizedVerseId)
        .toList(growable: false);
    updateUser(
      _user.copyWith(
        bookmarkedVerses: updatedBookmarks,
        savedVerses: updatedVerses,
      ),
    );
  }

  void addBookmark(String verseId) {
    final updated = List<String>.from(_user.bookmarkedVerses)..add(verseId);
    updateUser(_user.copyWith(bookmarkedVerses: updated));
  }

  void removeBookmark(String verseId) {
    final updated = List<String>.from(_user.bookmarkedVerses)..remove(verseId);
    updateUser(_user.copyWith(bookmarkedVerses: updated));
  }

  void addHighlightedVerse(String verseId) {
    final normalizedVerseId = verseId.trim();
    if (normalizedVerseId.isEmpty ||
        _user.highlightedVerses.contains(normalizedVerseId)) {
      return;
    }
    final updated = List<String>.from(_user.highlightedVerses)
      ..add(normalizedVerseId);
    updateUser(_user.copyWith(highlightedVerses: updated));
  }

  void removeHighlightedVerse(String verseId) {
    final normalizedVerseId = verseId.trim();
    if (normalizedVerseId.isEmpty ||
        !_user.highlightedVerses.contains(normalizedVerseId)) {
      return;
    }
    final updated = List<String>.from(_user.highlightedVerses)
      ..remove(normalizedVerseId);
    updateUser(_user.copyWith(highlightedVerses: updated));
  }

  void addFavoriteSong(String songId) {
    final updated = List<String>.from(_user.favoriteSongs)..add(songId);
    updateUser(_user.copyWith(favoriteSongs: updated));
  }

  void removeFavoriteSong(String songId) {
    final updated = List<String>.from(_user.favoriteSongs)..remove(songId);
    updateUser(_user.copyWith(favoriteSongs: updated));
  }

  void signIn({required String name, required String email}) {
    updateUser(_user.copyWith(
      authStatus: AuthStatus.loggedIn,
      name: name,
      email: email,
    ));
  }

  void signOut() {
    updateUser(_user.copyWith(
      authStatus: AuthStatus.guest,
      name: null,
      email: null,
    ));
  }

  static Map<String, int> _readIntMap(dynamic value) {
    if (value is! Map) {
      return const <String, int>{};
    }
    final normalized = <String, int>{};
    for (final entry in value.entries) {
      final key = entry.key?.toString().trim().toLowerCase() ?? '';
      final parsedValue = entry.value is int
          ? entry.value as int
          : int.tryParse(entry.value?.toString() ?? '');
      if (key.isNotEmpty && parsedValue != null && parsedValue > 0) {
        normalized[key] = parsedValue;
      }
    }
    return Map<String, int>.unmodifiable(normalized);
  }

  static Map<String, bool> _readBoolMap(dynamic value) {
    if (value is! Map) {
      return const <String, bool>{};
    }
    final normalized = <String, bool>{};
    for (final entry in value.entries) {
      final key = entry.key?.toString().trim().toLowerCase() ?? '';
      final parsedValue = entry.value is bool
          ? entry.value as bool
          : entry.value?.toString().trim().toLowerCase() == 'true';
      if (key.isNotEmpty) {
        normalized[key] = parsedValue;
      }
    }
    return Map<String, bool>.unmodifiable(normalized);
  }

  static Map<String, String> _readStringMap(dynamic value) {
    if (value is! Map) {
      return const <String, String>{};
    }
    final normalized = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key?.toString().trim().toLowerCase() ?? '';
      final parsedValue = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty && parsedValue.isNotEmpty) {
        normalized[key] = parsedValue;
      }
    }
    return Map<String, String>.unmodifiable(normalized);
  }

  static double _readBibleReaderTextScale(dynamic value) {
    final parsedValue = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsedValue == null) {
      return 1;
    }
    return parsedValue.clamp(
      _minBibleReaderTextScale,
      _maxBibleReaderTextScale,
    );
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((dynamic entry) => entry.toString().trim())
        .where((String entry) => entry.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static List<SavedVerseRecord> _readSavedVerses(dynamic value) {
    if (value is! List) {
      return const <SavedVerseRecord>[];
    }
    return value
        .whereType<Map>()
        .map<Map<String, dynamic>>(Map<String, dynamic>.from)
        .map(SavedVerseRecord.fromJson)
        .where(
          (SavedVerseRecord verse) =>
              verse.id.isNotEmpty &&
              verse.text.isNotEmpty &&
              verse.bookTitle.isNotEmpty,
        )
        .toList(growable: false);
  }

  static List<BookmarkCollection> _readBookmarkCollections(dynamic value) {
    if (value is! List) {
      return const <BookmarkCollection>[];
    }
    return value
        .whereType<Map>()
        .map<Map<String, dynamic>>(Map<String, dynamic>.from)
        .map(BookmarkCollection.fromJson)
        .where(
          (BookmarkCollection collection) =>
              collection.id.isNotEmpty && collection.name.isNotEmpty,
        )
        .toList(growable: false);
  }
}
