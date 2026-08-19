class MapsApiKey {
  MapsApiKey._();

  static const _keys = <String>[
    String.fromEnvironment('DART_MAPS_API_KEY'),
    String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
    String.fromEnvironment('ANDROID_MAPS_API_KEY'),
    String.fromEnvironment('IOS_MAPS_API_KEY'),
  ];

  static String get current {
    for (final key in _keys) {
      if (key.trim().isNotEmpty) {
        return key;
      }
    }

    return '';
  }
}
