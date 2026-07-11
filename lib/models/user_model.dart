import 'saved_verse_record.dart';

enum AppTheme { system, light, dark }

enum AuthStatus { guest, loggedIn }

class UserModel {
  final AuthStatus authStatus;
  final String? name;
  final String? email;
  final String bibleLanguage;
  final String songsLanguage;
  final AppTheme theme;
  final List<String> bookmarkedVerses;
  final List<String> highlightedVerses;
  final List<String> favoriteSongs;
  final List<SavedVerseRecord> savedVerses;
  final List<BookmarkCollection> bookmarkCollections;
  final Map<String, int> bibleVersionIdsByLanguage;
  final Map<String, bool> bibleAudioEnabledByLanguage;
  final Map<String, String> bibleAudioProfileByLanguage;
  final double bibleReaderTextScale;

  UserModel({
    this.authStatus = AuthStatus.guest,
    this.name,
    this.email,
    this.bibleLanguage = 'en',
    this.songsLanguage = 'en',
    this.theme = AppTheme.system,
    this.bookmarkedVerses = const [],
    this.highlightedVerses = const [],
    this.favoriteSongs = const [],
    this.savedVerses = const <SavedVerseRecord>[],
    this.bookmarkCollections = const <BookmarkCollection>[],
    this.bibleVersionIdsByLanguage = const <String, int>{},
    this.bibleAudioEnabledByLanguage = const <String, bool>{},
    this.bibleAudioProfileByLanguage = const <String, String>{},
    this.bibleReaderTextScale = 1,
  });

  static const Object _unset = Object();

  UserModel copyWith({
    AuthStatus? authStatus,
    Object? name = _unset,
    Object? email = _unset,
    String? bibleLanguage,
    String? songsLanguage,
    AppTheme? theme,
    List<String>? bookmarkedVerses,
    List<String>? highlightedVerses,
    List<String>? favoriteSongs,
    List<SavedVerseRecord>? savedVerses,
    List<BookmarkCollection>? bookmarkCollections,
    Map<String, int>? bibleVersionIdsByLanguage,
    Map<String, bool>? bibleAudioEnabledByLanguage,
    Map<String, String>? bibleAudioProfileByLanguage,
    double? bibleReaderTextScale,
  }) {
    return UserModel(
      authStatus: authStatus ?? this.authStatus,
      name: identical(name, _unset) ? this.name : name as String?,
      email: identical(email, _unset) ? this.email : email as String?,
      bibleLanguage: bibleLanguage ?? this.bibleLanguage,
      songsLanguage: songsLanguage ?? this.songsLanguage,
      theme: theme ?? this.theme,
      bookmarkedVerses: bookmarkedVerses ?? this.bookmarkedVerses,
      highlightedVerses: highlightedVerses ?? this.highlightedVerses,
      favoriteSongs: favoriteSongs ?? this.favoriteSongs,
      savedVerses: savedVerses ?? this.savedVerses,
      bookmarkCollections: bookmarkCollections ?? this.bookmarkCollections,
      bibleVersionIdsByLanguage:
          bibleVersionIdsByLanguage ?? this.bibleVersionIdsByLanguage,
      bibleAudioEnabledByLanguage:
          bibleAudioEnabledByLanguage ?? this.bibleAudioEnabledByLanguage,
      bibleAudioProfileByLanguage:
          bibleAudioProfileByLanguage ?? this.bibleAudioProfileByLanguage,
      bibleReaderTextScale: bibleReaderTextScale ?? this.bibleReaderTextScale,
    );
  }
}
