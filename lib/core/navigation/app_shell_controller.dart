import 'package:flutter/material.dart';

class AppShellController extends ChangeNotifier {
  static const int homeIndex = 0;
  static const int searchIndex = 1;
  static const int wishlistIndex = 2;
  static const int profileIndex = 3;
  static const int cartIndex = 4;

  int _currentIndex = homeIndex;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (index == _currentIndex) {
      return;
    }

    _currentIndex = index;
    notifyListeners();
  }

  void goHome() => setIndex(homeIndex);

  void goToProfile() => setIndex(profileIndex);

  void reset() {
    if (_currentIndex == homeIndex) {
      return;
    }

    _currentIndex = homeIndex;
    notifyListeners();
  }
}
