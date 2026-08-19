import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseRuntimeOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return null;
    }

    if (Platform.isAndroid) {
      return _buildOptions(
        apiKey: const String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
        messagingSenderId: const String.fromEnvironment(
          'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
        ),
        projectId: const String.fromEnvironment('FIREBASE_ANDROID_PROJECT_ID'),
        storageBucket: const String.fromEnvironment(
          'FIREBASE_ANDROID_STORAGE_BUCKET',
        ),
      );
    }

    if (Platform.isIOS) {
      return _buildOptions(
        apiKey: const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
        appId: const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
        messagingSenderId: const String.fromEnvironment(
          'FIREBASE_IOS_MESSAGING_SENDER_ID',
        ),
        projectId: const String.fromEnvironment('FIREBASE_IOS_PROJECT_ID'),
        storageBucket: const String.fromEnvironment(
          'FIREBASE_IOS_STORAGE_BUCKET',
        ),
        iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      );
    }

    return null;
  }

  static FirebaseOptions? _buildOptions({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
    String? storageBucket,
    String? iosBundleId,
  }) {
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket != null && storageBucket.isNotEmpty
          ? storageBucket
          : null,
      iosBundleId: iosBundleId != null && iosBundleId.isNotEmpty
          ? iosBundleId
          : null,
    );
  }
}
