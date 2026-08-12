import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:uuid/uuid.dart';
import '../../../config/api_config.dart';
import '../models/location_model.dart';

/// Service for Google Maps, Places, Geocoding and Fallback Location services.
class LocationService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  Position? _currentPosition;
  String _sessionToken = const Uuid().v4();

  static const String _googleApiKey = ApiConfig.googleMapsApiKey;

  static const List<LocationModel> popularCities = [
    LocationModel(
      id: 'pop_delhi',
      name: 'New Delhi',
      fullAddress: 'New Delhi, Delhi, India',
      secondaryAddress: 'Delhi, India',
      latitude: 28.6139,
      longitude: 77.2090,
    ),
    LocationModel(
      id: 'pop_gurugram',
      name: 'Gurugram',
      fullAddress: 'Gurugram, Haryana, India',
      secondaryAddress: 'Haryana, India',
      latitude: 28.4595,
      longitude: 77.0266,
    ),
    LocationModel(
      id: 'pop_noida',
      name: 'Noida',
      fullAddress: 'Noida, Uttar Pradesh, India',
      secondaryAddress: 'Uttar Pradesh, India',
      latitude: 28.5355,
      longitude: 77.3910,
    ),
    LocationModel(
      id: 'pop_bengaluru',
      name: 'Bengaluru',
      fullAddress: 'Bengaluru, Karnataka, India',
      secondaryAddress: 'Karnataka, India',
      latitude: 12.9716,
      longitude: 77.5946,
    ),
    LocationModel(
      id: 'pop_mumbai',
      name: 'Mumbai',
      fullAddress: 'Mumbai, Maharashtra, India',
      secondaryAddress: 'Maharashtra, India',
      latitude: 19.0760,
      longitude: 72.8777,
    ),
    LocationModel(
      id: 'pop_hyderabad',
      name: 'Hyderabad',
      fullAddress: 'Hyderabad, Telangana, India',
      secondaryAddress: 'Telangana, India',
      latitude: 17.3850,
      longitude: 78.4867,
    ),
    LocationModel(
      id: 'pop_pune',
      name: 'Pune',
      fullAddress: 'Pune, Maharashtra, India',
      secondaryAddress: 'Maharashtra, India',
      latitude: 18.5204,
      longitude: 73.8567,
    ),
    LocationModel(
      id: 'pop_chennai',
      name: 'Chennai',
      fullAddress: 'Chennai, Tamil Nadu, India',
      secondaryAddress: 'Tamil Nadu, India',
      latitude: 13.0827,
      longitude: 80.2707,
    ),
    LocationModel(
      id: 'pop_kolkata',
      name: 'Kolkata',
      fullAddress: 'Kolkata, West Bengal, India',
      secondaryAddress: 'West Bengal, India',
      latitude: 22.5726,
      longitude: 88.3639,
    ),
    LocationModel(
      id: 'pop_ahmedabad',
      name: 'Ahmedabad',
      fullAddress: 'Ahmedabad, Gujarat, India',
      secondaryAddress: 'Gujarat, India',
      latitude: 23.0225,
      longitude: 72.5714,
    ),
    LocationModel(
      id: 'pop_jaipur',
      name: 'Jaipur',
      fullAddress: 'Jaipur, Rajasthan, India',
      secondaryAddress: 'Rajasthan, India',
      latitude: 26.9124,
      longitude: 75.7873,
    ),
    LocationModel(
      id: 'pop_chandigarh',
      name: 'Chandigarh',
      fullAddress: 'Chandigarh, Punjab & Haryana, India',
      secondaryAddress: 'Punjab & Haryana, India',
      latitude: 30.7333,
      longitude: 76.7794,
    ),
    LocationModel(
      id: 'pop_lucknow',
      name: 'Lucknow',
      fullAddress: 'Lucknow, Uttar Pradesh, India',
      secondaryAddress: 'Uttar Pradesh, India',
      latitude: 26.8467,
      longitude: 80.9462,
    ),
    LocationModel(
      id: 'pop_indore',
      name: 'Indore',
      fullAddress: 'Indore, Madhya Pradesh, India',
      secondaryAddress: 'Madhya Pradesh, India',
      latitude: 22.7196,
      longitude: 75.8577,
    ),
    LocationModel(
      id: 'pop_dehradun',
      name: 'Dehradun',
      fullAddress: 'Dehradun, Uttarakhand, India',
      secondaryAddress: 'Uttarakhand, India',
      latitude: 30.3165,
      longitude: 78.0322,
    ),
  ];

  void resetSessionToken() {
    _sessionToken = const Uuid().v4();
    debugPrint('[Places] New session token generated');
  }

  String get sessionToken => _sessionToken;

  List<LocationModel> filterPopularCities(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return popularCities;
    return popularCities
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.fullAddress.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Updates local cache of current position for biased search.
  void updateCurrentPosition(Position pos) => _currentPosition = pos;

  /// Requests permissions, checks location services, and fetches current Position.
  Future<Position?> determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    debugPrint('Location service: $serviceEnabled');

    if (!serviceEnabled) {
      debugPrint('ERROR: Phone location is OFF');
      await Geolocator.openLocationSettings();
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    debugPrint('Location permission before request: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      debugPrint('Location permission after request: $permission');
    }

    if (permission == LocationPermission.denied) {
      debugPrint('ERROR: Location permission denied');
      return null;
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('ERROR: Location permission denied forever');
      await Geolocator.openAppSettings();
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    updateCurrentPosition(position);

    return position;
  }

  /// Fetch Places Autocomplete suggestions with session token and fallback tiers.
  Future<List<LocationModel>> getSuggestions(
    String query, {
    String? sessionToken,
    CancelToken? cancelToken,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final token = sessionToken ?? _sessionToken;

    debugPrint('[Places] requesting predictions');

    final apiKey = ApiConfig.placesApiKey;
    if (apiKey.isEmpty) {
      debugPrint('[Places] Google Places REST key is missing');
    } else {
      try {
        Map<String, String>? headers;
        try {
          headers = await const GoogleApiHeaders().getHeaders();
        } catch (_) {}

        final list = await _fetchGooglePlaces(
          cleanQuery,
          token: token,
          apiKey: apiKey,
          headers: headers,
          cancelToken: cancelToken,
        );
        if (list.isNotEmpty) return list;
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
        debugPrint('[Places] Google Places exception: $e');
      }
    }

    // Tier 2: Photon API (Fast, comprehensive place predictions)
    try {
      final list = await _fetchPhoton(cleanQuery, cancelToken: cancelToken);
      if (list.isNotEmpty) {
        debugPrint(
          '[Places] Photon fallback returned ${list.length} predictions',
        );
        return list;
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      debugPrint('[Places] Photon search exception: $e');
    }

    // Tier 3: Google Geocoding API
    if (apiKey.isNotEmpty) {
      try {
        final list = await _fetchGoogleGeocoding(
          cleanQuery,
          apiKey: apiKey,
          cancelToken: cancelToken,
        );
        if (list.isNotEmpty) {
          debugPrint('[Places] Geocoding returned ${list.length} predictions');
          return list;
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
        debugPrint('[Places] Google Geocoding exception: $e');
      }
    }

    // Tier 4: Local Popular Cities Fallback
    final fallbacks = filterPopularCities(cleanQuery);
    debugPrint(
      '[Places] Popular cities fallback returned ${fallbacks.length} predictions',
    );
    return fallbacks;
  }

  Future<List<LocationModel>> _fetchGooglePlaces(
    String query, {
    required String token,
    required String apiKey,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    final queryParams = <String, dynamic>{
      'input': query,
      'key': apiKey,
      'components': 'country:in',
      'sessiontoken': token,
      if (_currentPosition != null)
        'location':
            '${_currentPosition!.latitude},${_currentPosition!.longitude}',
      if (_currentPosition != null) 'radius': '50000',
    };

    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      queryParameters: queryParams,
      options: headers != null ? Options(headers: headers) : null,
      cancelToken: cancelToken,
    );

    debugPrint('[Places] HTTP status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final status = response.data['status'] as String? ?? '';
      final errorMsg = response.data['error_message'] as String?;
      final List? predictions = response.data['predictions'] as List?;

      if (status == 'OK' && predictions != null && predictions.isNotEmpty) {
        debugPrint('[Places] predictions: ${predictions.length}');
        return predictions.map((p) {
          final structured =
              p['structured_formatting'] as Map<String, dynamic>? ?? {};
          final mainText =
              structured['main_text'] as String? ??
              p['description'] as String? ??
              '';
          final secondaryText = structured['secondary_text'] as String? ?? '';
          return LocationModel(
            id: p['place_id'] as String? ?? '',
            name: mainText,
            fullAddress: p['description'] as String? ?? '',
            secondaryAddress: secondaryText,
            latitude: 0,
            longitude: 0,
          );
        }).toList();
      } else {
        debugPrint(
          '[Places] status: $status ${errorMsg != null ? "- $errorMsg" : ""}',
        );
        if (status == 'REQUEST_DENIED') {
          debugPrint('[Places] error: REQUEST_DENIED');
        } else if (status == 'ZERO_RESULTS') {
          debugPrint('[Places] error: ZERO_RESULTS');
        }
      }
    }
    return [];
  }

  Future<List<LocationModel>> _fetchPhoton(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{'q': query, 'limit': 8};
    if (_currentPosition != null) {
      params['lat'] = _currentPosition!.latitude;
      params['lon'] = _currentPosition!.longitude;
    }

    final response = await _dio.get(
      'https://photon.komoot.io/api/',
      queryParameters: params,
      options: Options(headers: {'User-Agent': 'AgoApp/1.0 (Mobile App)'}),
      cancelToken: cancelToken,
    );

    if (response.statusCode == 200 && response.data != null) {
      final List features = response.data['features'] ?? [];
      final list = <LocationModel>[];
      for (final f in features) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final coords = f['geometry']?['coordinates'] as List? ?? [];
        if (coords.length < 2) continue;

        final name = props['name'] as String? ?? '';
        if (name.isEmpty) continue;

        final parts = <String>[];
        if (props['street'] != null) parts.add(props['street']);
        if (props['district'] != null) parts.add(props['district']);
        if (props['city'] != null) parts.add(props['city']);
        if (props['state'] != null) parts.add(props['state']);
        if (props['country'] != null) parts.add(props['country']);

        final fullAddress = parts.isNotEmpty
            ? '$name, ${parts.join(', ')}'
            : name;
        final secondary = parts.join(', ');

        final lat = (coords[1] as num).toDouble();
        final lng = (coords[0] as num).toDouble();

        list.add(
          LocationModel(
            id: 'photon_${props['osm_id'] ?? name.hashCode}',
            name: name,
            fullAddress: fullAddress,
            secondaryAddress: secondary,
            city: props['city'] as String?,
            state: props['state'] as String?,
            country: props['country'] as String?,
            latitude: lat,
            longitude: lng,
          ),
        );
      }
      return list;
    }
    return [];
  }

  Future<List<LocationModel>> _fetchGoogleGeocoding(
    String query, {
    required String apiKey,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/geocode/json',
      queryParameters: {
        'address': query,
        'components': 'country:in',
        'key': apiKey,
      },
      cancelToken: cancelToken,
    );

    if (response.statusCode == 200 && response.data['status'] == 'OK') {
      final List results = response.data['results'];
      return results.map((r) {
        final loc = r['geometry']['location'];
        final address = r['formatted_address'] as String;
        final name = address.split(',').first.trim();
        final secondary = address.contains(',')
            ? address.substring(address.indexOf(',') + 1).trim()
            : '';

        return LocationModel(
          id: 'geo_${r['place_id'] ?? address.hashCode}',
          name: name,
          fullAddress: address,
          secondaryAddress: secondary,
          latitude: (loc['lat'] as num).toDouble(),
          longitude: (loc['lng'] as num).toDouble(),
        );
      }).toList();
    }
    return [];
  }

  /// Fetches exact coordinates for a specific Place ID using Place Details API.
  Future<Map<String, double>?> getPlaceCoordinates(
    String placeId, {
    String? sessionToken,
  }) async {
    if (placeId.isEmpty ||
        placeId.startsWith('photon_') ||
        placeId.startsWith('osm_') ||
        placeId.startsWith('pop_') ||
        placeId.startsWith('geo_')) {
      return null;
    }
    final token = sessionToken ?? _sessionToken;
    final apiKey = ApiConfig.placesApiKey;
    if (apiKey.isEmpty) {
      debugPrint('[Places] Google Places REST key is missing');
      return null;
    }

    try {
      Map<String, String>? headers;
      try {
        headers = await const GoogleApiHeaders().getHeaders();
      } catch (_) {}

      final res = await _fetchPlaceDetails(
        placeId,
        token: token,
        apiKey: apiKey,
        headers: headers,
      );
      if (res != null) return res;
    } catch (e) {
      debugPrint('[Places] Place details exception: $e');
    }

    return null;
  }

  Future<Map<String, double>?> _fetchPlaceDetails(
    String placeId, {
    required String token,
    required String apiKey,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.get(
      'https://maps.googleapis.com/maps/api/place/details/json',
      queryParameters: {
        'place_id': placeId,
        'fields': 'geometry,name,formatted_address',
        'key': apiKey,
        'sessiontoken': token,
      },
      options: headers != null ? Options(headers: headers) : null,
    );

    if (response.statusCode == 200 && response.data['status'] == 'OK') {
      final location = response.data['result']['geometry']['location'];
      resetSessionToken();
      return {
        'lat': (location['lat'] as num).toDouble(),
        'lng': (location['lng'] as num).toDouble(),
      };
    } else {
      final status = response.data['status'] as String? ?? '';
      debugPrint('[Places] Place details status: $status');
    }
    return null;
  }

  /// Reverse geocoding using Google Geocoding API with multi-tier fallbacks (Nominatim & BigDataCloud).
  Future<String?> reverseGeocode(double lat, double lng) async {
    // 1. Try Google Geocoding API
    try {
      final headers = await const GoogleApiHeaders().getHeaders();
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'latlng': '$lat,$lng', 'key': _googleApiKey},
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final String address = results[0]['formatted_address'] ?? '';
          if (address.trim().isNotEmpty) {
            return address.trim();
          }
        }
      } else {
        debugPrint(
          '[Places] Google Geocode status: ${response.data['status']} - error: ${response.data['error_message']}',
        );
      }
    } catch (e) {
      debugPrint('[Places] Google Geocode Exception: $e');
    }

    // 2. Fallback to OpenStreetMap Nominatim
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'accept-language': 'en',
        },
        options: Options(headers: {'User-Agent': 'AGoApp/1.0'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final displayName = response.data['display_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          return displayName.trim();
        }
      }
    } catch (e) {
      debugPrint('[Places] Nominatim Geocode Exception: $e');
    }

    // 3. Fallback to BigDataCloud Free Reverse Geocode
    try {
      final response = await _dio.get(
        'https://api.bigdatacloud.net/data/reverse-geocode-client',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'localityLanguage': 'en',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final locality =
            data['locality'] ??
            data['city'] ??
            data['localityInfo']?['informative']?[0]?['name'] ??
            '';
        final state = data['principalSubdivision'] ?? '';
        final country = data['countryName'] ?? '';
        final parts = [
          locality,
          state,
          country,
        ].where((p) => p.toString().trim().isNotEmpty).join(', ');
        if (parts.trim().isNotEmpty) {
          return parts.trim();
        }
      }
    } catch (e) {
      debugPrint('[Places] BigDataCloud Geocode Exception: $e');
    }

    return null;
  }
}
