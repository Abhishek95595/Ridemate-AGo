class ApiConfig {
  ApiConfig._();

  /// Native Maps SDK key supplied at build time.
  static const String googleMapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  /// Places REST Web Service key supplied at build time.
  static const String placesApiKey = String.fromEnvironment('PLACES_API_KEY');

  /// Routes REST Web Service key supplied at build time.
  static String get routesApiKey {
    const key = String.fromEnvironment('ROUTES_API_KEY');
    if (key.isNotEmpty) return key;
    const mapsKey = String.fromEnvironment('MAPS_API_KEY');
    if (mapsKey.isNotEmpty) return mapsKey;
    const placesKey = String.fromEnvironment('PLACES_API_KEY');
    if (placesKey.isNotEmpty) return placesKey;
    return '';
  }
}

