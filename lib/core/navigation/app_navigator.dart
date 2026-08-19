import 'package:flutter/material.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get state => navigatorKey.currentState;

  static BuildContext? get context => navigatorKey.currentContext;

  static void popToRoot() {
    state?.popUntil((route) => route.isFirst);
  }
}
