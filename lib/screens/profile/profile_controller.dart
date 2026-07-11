import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class ProfileController extends ChangeNotifier {
  final UserService userService;
  final AuthService _authService;

  ProfileController({
    required this.userService,
    AuthService? authService,
  }) : _authService = authService ?? AuthService() {
    userService.addListener(notifyListeners);
  }

  @override
  void dispose() {
    userService.removeListener(notifyListeners);
    super.dispose();
  }

  // Expose user data
  get user => userService.user;

  // Proxy methods
  void setBibleLanguage(String lang) => userService.setBibleLanguage(lang);
  void setSongsLanguage(String lang) => userService.setSongsLanguage(lang);
  void setTheme(AppTheme theme) => userService.setTheme(theme);
  void signIn({required String name, required String email}) =>
      userService.signIn(name: name, email: email);
  Future<void> signOut() async {
    await _authService.logout();
    userService.signOut();
  }

  void addBookmark(String verseId) => userService.addBookmark(verseId);
  void removeBookmark(String verseId) => userService.removeBookmark(verseId);
  void addFavoriteSong(String songId) => userService.addFavoriteSong(songId);
  void removeFavoriteSong(String songId) =>
      userService.removeFavoriteSong(songId);
}
