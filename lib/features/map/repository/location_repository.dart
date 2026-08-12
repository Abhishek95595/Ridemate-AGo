import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

/// Repository handling location data orchestration and caching.
class LocationRepository {
  final LocationService _service;
  final SharedPreferences _prefs;
  static const String _recentSearchesKey = 'recent_locations_v2';

  LocationRepository(this._service, this._prefs);

  /// Main search method with Google Places primary.
  Future<List<LocationModel>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    return await _service.getSuggestions(query, cancelToken: cancelToken);
  }

  /// Fetches coordinates for a place if not present.
  Future<LocationModel> getDetails(LocationModel location) async {
    if (location.latitude != 0 && location.longitude != 0) return location;

    final coords = await _service.getPlaceCoordinates(location.id);
    if (coords != null) {
      return location.copyWith(
        latitude: coords['lat'],
        longitude: coords['lng'],
      );
    }
    return location;
  }

  /// Manages local caching of recent searches.
  Future<void> saveToRecents(LocationModel location) async {
    final recents = getRecentSearches();

    // Remove if already exists (to move to top)
    recents.removeWhere((l) => l.fullAddress == location.fullAddress);
    recents.insert(0, location);

    // Limit to 5
    if (recents.length > 5) recents.removeLast();

    final jsonList = recents.map((l) => jsonEncode(l.toJson())).toList();
    await _prefs.setStringList(_recentSearchesKey, jsonList);
  }

  List<LocationModel> getRecentSearches() {
    final list = _prefs.getStringList(_recentSearchesKey) ?? [];
    return list.map((s) => LocationModel.fromJson(jsonDecode(s))).toList();
  }

  List<LocationModel> getPopularCities() {
    return LocationService.popularCities;
  }

  List<LocationModel> filterPopularCities(String query) {
    return _service.filterPopularCities(query);
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    return await _service.reverseGeocode(lat, lng);
  }
}
