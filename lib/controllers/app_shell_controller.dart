import 'package:flutter/material.dart';

import '../services/audio_coordinator.dart';

class AppShellController extends ChangeNotifier {
  static const int homeIndex = 0;
  static const int bibleIndex = 1;
  static const int hymnsIndex = 2;
  static const int musicIndex = 3;
  static const int profileIndex = 4;
  static const int tabCount = 5;

  int _selectedIndex = 0;
  bool _showNavigationBar = true;

  int get selectedIndex => _selectedIndex;
  bool get showNavigationBar => _showNavigationBar;

  void selectTab(int index) {
    if (index < 0 || index >= tabCount) {
      return;
    }
    if (_selectedIndex == index) {
      return;
    }
    AudioCoordinator.instance.onTabChanging(_selectedIndex, index);
    _selectedIndex = index;
    notifyListeners();
  }

  void openHome() {
    selectTab(homeIndex);
  }

  void openHymns() {
    selectTab(hymnsIndex);
  }

  void setNavigationBarVisible(bool visible) {
    if (_showNavigationBar == visible) {
      return;
    }
    _showNavigationBar = visible;
    notifyListeners();
  }
}
