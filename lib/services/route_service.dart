import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/api_config.dart';

/// Service responsible for fetching driving routes, polylines,
/// distances, and durations.
///
/// Priority:
/// 1. Google Routes API v2
/// 2. Legacy Directions API
/// 3. Straight-line fallback
class RouteService {
  static String get _googleApiKey => ApiConfig.routesApiKey;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.json,
    ),
  );

  // ------------------------------------------------------------
  // VALIDATE LAT/LNG
  // ------------------------------------------------------------

  bool _isValidPoint(LatLng point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  // ------------------------------------------------------------
  // DECODE GOOGLE ENCODED POLYLINE
  // ------------------------------------------------------------

  List<LatLng> _decodePolyline(String polyline) {
    if (polyline.isEmpty) {
      return [];
    }

    final List<LatLng> points = [];

    int index = 0;
    int latitude = 0;
    int longitude = 0;

    try {
      while (index < polyline.length) {
        int shift = 0;
        int result = 0;
        int byte;

        do {
          if (index >= polyline.length) break;
          byte = polyline.codeUnitAt(index++) - 63;
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);

        final int deltaLatitude = (result & 1) != 0
            ? ~(result >> 1)
            : (result >> 1);

        latitude += deltaLatitude;

        shift = 0;
        result = 0;

        do {
          if (index >= polyline.length) break;
          byte = polyline.codeUnitAt(index++) - 63;
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);

        final int deltaLongitude = (result & 1) != 0
            ? ~(result >> 1)
            : (result >> 1);

        longitude += deltaLongitude;

        points.add(LatLng(latitude / 1E5, longitude / 1E5));
      }
    } catch (e) {
      debugPrint('[RouteService] Exception during polyline decoding: $e');
    }

    return points;
  }

  // ------------------------------------------------------------
  // GET ROUTE DETAILS
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> getRouteDetails(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      debugPrint('[RouteService] At least 2 waypoints are required.');
      return null;
    }

    if (!waypoints.every(_isValidPoint)) {
      debugPrint('[RouteService] Invalid LatLng detected.');
      return null;
    }

    debugPrint(
      '[RouteService] Routes key configured: ${_googleApiKey.isNotEmpty}',
    );

    // ----------------------------------------------------------
    // 1. GOOGLE ROUTES API V2 (Requires API key)
    // ----------------------------------------------------------

    if (_googleApiKey.isNotEmpty) {
      try {
        final result = await _fetchRoutesApiV2(waypoints);

        if (result != null) {
          debugPrint('[RouteService] Routes API v2 successful.');
          return result;
        }
      } on DioException catch (e) {
        debugPrint('[RouteService] Routes API v2 ERROR');
        debugPrint('[RouteService] Method: ${e.requestOptions.method}');
        debugPrint('[RouteService] Status: ${e.response?.statusCode}');
        debugPrint('[RouteService] Message: ${e.message}');
      } catch (e, stackTrace) {
        debugPrint('[RouteService] Routes API v2 exception: $e');
        debugPrintStack(stackTrace: stackTrace);
      }

      // ----------------------------------------------------------
      // 2. LEGACY DIRECTIONS API (Requires API key)
      // ----------------------------------------------------------

      try {
        final result = await _fetchLegacyDirections(waypoints);

        if (result != null) {
          debugPrint('[RouteService] Legacy Directions API successful.');
          return result;
        }
      } on DioException catch (e) {
        debugPrint('[RouteService] Legacy Directions API ERROR');
        debugPrint('[RouteService] Status: ${e.response?.statusCode}');
        debugPrint('[RouteService] Message: ${e.message}');
      } catch (e, stackTrace) {
        debugPrint('[RouteService] Legacy Directions exception: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    } else {
      debugPrint(
        '[RouteService] Google API key is empty; proceeding directly to free routing engines.',
      );
    }

    // ----------------------------------------------------------
    // 3. OSRM FREE ROUTING API (No API key required)
    // ----------------------------------------------------------

    try {
      final result = await _fetchOsrmRoute(waypoints);

      if (result != null) {
        debugPrint('[RouteService] OSRM Routing successful.');
        return result;
      }
    } on DioException catch (e) {
      debugPrint('[RouteService] OSRM API ERROR');
      debugPrint('[RouteService] Status: ${e.response?.statusCode}');
      debugPrint('[RouteService] Message: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[RouteService] OSRM Routing exception: $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    // ----------------------------------------------------------
    // 4. STRAIGHT-LINE FALLBACK
    // ----------------------------------------------------------

    return _buildStraightLineFallback(waypoints);
  }

  // ------------------------------------------------------------
  // GOOGLE ROUTES API V2
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchRoutesApiV2(
    List<LatLng> waypoints,
  ) async {
    final LatLng origin = waypoints.first;
    final LatLng destination = waypoints.last;

    final Map<String, dynamic> body = {
      'origin': {
        'location': {
          'latLng': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'computeAlternativeRoutes': false,
      'languageCode': 'en-US',
      'units': 'METRIC',
    };

    // Add intermediate waypoints if supplied.
    if (waypoints.length > 2) {
      body['intermediates'] = waypoints
          .sublist(1, waypoints.length - 1)
          .map(
            (LatLng point) => {
              'location': {
                'latLng': {
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                },
              },
            },
          )
          .toList();
    }

    debugPrint(
      '[RouteService] Routes API request: '
      '${origin.latitude},${origin.longitude} -> '
      '${destination.latitude},${destination.longitude}',
    );

    final Response<dynamic> response = await _dio.post(
      // IMPORTANT:
      // Correct Google Routes API endpoint.
      'https://routes.googleapis.com/directions/v2:computeRoutes',
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleApiKey,
          'X-Goog-FieldMask':
              'routes.duration,'
              'routes.distanceMeters,'
              'routes.polyline.encodedPolyline',
        },
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );

    debugPrint(
      '[RouteService] Routes API v2 HTTP status: ${response.statusCode}',
    );

    if (response.statusCode != 200) {
      return null;
    }

    final dynamic responseData = response.data;

    if (responseData is! Map) {
      debugPrint('[RouteService] Invalid Routes API response.');
      return null;
    }

    final dynamic routesData = responseData['routes'];

    if (routesData is! List || routesData.isEmpty) {
      debugPrint('[RouteService] Routes API returned no routes.');
      return null;
    }

    final dynamic firstRoute = routesData.first;

    if (firstRoute is! Map) {
      debugPrint('[RouteService] Invalid route object.');
      return null;
    }

    // ----------------------------------------------------------
    // POLYLINE
    // ----------------------------------------------------------

    final dynamic polylineData = firstRoute['polyline'];

    String encodedPolyline = '';

    if (polylineData is Map) {
      encodedPolyline = polylineData['encodedPolyline']?.toString() ?? '';
    }

    if (encodedPolyline.isEmpty) {
      debugPrint('[RouteService] Encoded polyline is empty.');
      return null;
    }

    final List<LatLng> points = _decodePolyline(encodedPolyline);

    if (points.isEmpty) {
      debugPrint('[RouteService] Polyline decoding returned 0 points.');
      return null;
    }

    // ----------------------------------------------------------
    // DISTANCE
    // ----------------------------------------------------------

    final double distanceMeters =
        (firstRoute['distanceMeters'] as num?)?.toDouble() ?? 0;

    // ----------------------------------------------------------
    // DURATION
    // ----------------------------------------------------------

    double durationSeconds = 0;

    final String? rawDuration = firstRoute['duration']?.toString();

    if (rawDuration != null && rawDuration.endsWith('s')) {
      durationSeconds =
          double.tryParse(rawDuration.substring(0, rawDuration.length - 1)) ??
          0;
    }

    debugPrint('[RouteService] Road route loaded: ${points.length} points.');

    debugPrint(
      '[RouteService] Distance: '
      '${(distanceMeters / 1000).toStringAsFixed(2)} km',
    );

    debugPrint(
      '[RouteService] Duration: '
      '${(durationSeconds / 60).round()} min',
    );

    return {
      'points': points,
      'distance': distanceMeters,
      'duration': durationSeconds,
      'isFallback': false,
      'source': 'routes_api_v2',
    };
  }

  // ------------------------------------------------------------
  // LEGACY DIRECTIONS API
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchLegacyDirections(
    List<LatLng> waypoints,
  ) async {
    final LatLng originPoint = waypoints.first;
    final LatLng destinationPoint = waypoints.last;

    final String origin = '${originPoint.latitude},${originPoint.longitude}';

    final String destination =
        '${destinationPoint.latitude},${destinationPoint.longitude}';

    final Map<String, dynamic> queryParameters = {
      'origin': origin,
      'destination': destination,
      'mode': 'driving',
      'key': _googleApiKey,
    };

    if (waypoints.length > 2) {
      queryParameters['waypoints'] = waypoints
          .sublist(1, waypoints.length - 1)
          .map((LatLng point) => '${point.latitude},${point.longitude}')
          .join('|');
    }

    final Response<dynamic> response = await _dio.get(
      'https://maps.googleapis.com/maps/api/directions/json',
      queryParameters: queryParameters,
      options: Options(
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );

    debugPrint(
      '[RouteService] Legacy Directions status: '
      '${response.statusCode}',
    );

    if (response.statusCode != 200) {
      debugPrint(
        '[RouteService] Legacy Directions HTTP response: '
        '${response.data}',
      );

      return null;
    }

    final dynamic responseData = response.data;

    if (responseData is! Map) {
      return null;
    }

    final String status = responseData['status']?.toString() ?? 'UNKNOWN';

    if (status != 'OK') {
      debugPrint('[RouteService] Legacy Directions status=$status');

      debugPrint(
        '[RouteService] Legacy error: '
        '${responseData['error_message']}',
      );

      return null;
    }

    final dynamic routesData = responseData['routes'];

    if (routesData is! List || routesData.isEmpty) {
      return null;
    }

    final dynamic firstRoute = routesData.first;

    if (firstRoute is! Map) {
      return null;
    }

    // ----------------------------------------------------------
    // POLYLINE
    // ----------------------------------------------------------

    final dynamic overviewPolyline = firstRoute['overview_polyline'];

    if (overviewPolyline is! Map) {
      return null;
    }

    final String encodedPolyline = overviewPolyline['points']?.toString() ?? '';

    if (encodedPolyline.isEmpty) {
      return null;
    }

    final List<LatLng> points = _decodePolyline(encodedPolyline);

    // ----------------------------------------------------------
    // SUM ALL LEGS
    // ----------------------------------------------------------

    double totalDistance = 0;
    double totalDuration = 0;

    final dynamic legs = firstRoute['legs'];

    if (legs is List) {
      for (final dynamic leg in legs) {
        if (leg is! Map) continue;

        final dynamic distance = leg['distance'];
        final dynamic duration = leg['duration'];

        if (distance is Map) {
          totalDistance += (distance['value'] as num?)?.toDouble() ?? 0;
        }

        if (duration is Map) {
          totalDuration += (duration['value'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    debugPrint(
      '[RouteService] Legacy road route loaded: '
      '${points.length} points.',
    );

    return {
      'points': points,
      'distance': totalDistance,
      'duration': totalDuration,
      'isFallback': false,
      'source': 'legacy_directions',
    };
  }

  // ------------------------------------------------------------
  // OSRM FREE ROUTING API
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchOsrmRoute(
    List<LatLng> waypoints,
  ) async {
    final String waypointsString = waypoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');

    final List<String> osrmBaseUrls = [
      'https://router.project-osrm.org/route/v1/driving/',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving/',
    ];

    for (final String baseUrl in osrmBaseUrls) {
      final String url =
          '$baseUrl$waypointsString?overview=full&geometries=polyline';

      debugPrint('[RouteService] OSRM request: $url');

      try {
        final Response<dynamic> response = await _dio.get(
          url,
          options: Options(
            headers: const {
              'User-Agent': 'AgoApp/1.0 (Mobile App)',
              'Accept': 'application/json',
            },
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode != 200 || response.data is! Map) {
          debugPrint(
            '[RouteService] OSRM status failed on $baseUrl: ${response.statusCode}',
          );
          continue;
        }

        final Map<String, dynamic> responseData =
            Map<String, dynamic>.from(response.data);

        if (responseData['code'] != 'Ok') {
          debugPrint('[RouteService] OSRM code: ${responseData['code']}');
          continue;
        }

        final dynamic routesData = responseData['routes'];

        if (routesData is! List || routesData.isEmpty) {
          continue;
        }

        final dynamic firstRoute = routesData.first;

        if (firstRoute is! Map) {
          continue;
        }

        final String encodedPolyline =
            firstRoute['geometry']?.toString() ?? '';

        if (encodedPolyline.isEmpty) {
          continue;
        }

        final List<LatLng> points = _decodePolyline(encodedPolyline);

        if (points.isEmpty) {
          continue;
        }

        final double distanceMeters =
            (firstRoute['distance'] as num?)?.toDouble() ?? 0;
        final double durationSeconds =
            (firstRoute['duration'] as num?)?.toDouble() ?? 0;

        debugPrint(
          '[RouteService] OSRM road route loaded: ${points.length} points from $baseUrl.',
        );

        return {
          'points': points,
          'distance': distanceMeters,
          'duration': durationSeconds,
          'isFallback': false,
          'source': 'osrm',
        };
      } catch (e) {
        debugPrint('[RouteService] OSRM mirror error ($baseUrl): $e');
      }
    }

    return null;
  }

  // ------------------------------------------------------------
  // STRAIGHT LINE FALLBACK
  // ------------------------------------------------------------

  Map<String, dynamic>? _buildStraightLineFallback(List<LatLng> waypoints) {
    try {
      double totalDistance = 0;

      for (int i = 0; i < waypoints.length - 1; i++) {
        totalDistance += Geolocator.distanceBetween(
          waypoints[i].latitude,
          waypoints[i].longitude,
          waypoints[i + 1].latitude,
          waypoints[i + 1].longitude,
        );
      }

      // Approximate city speed = 30 km/h = 8.33 m/s.
      final double estimatedDurationSeconds = totalDistance / 8.33;

      debugPrint(
        '[RouteService] Using straight-line fallback. '
        'Distance: '
        '${(totalDistance / 1000).toStringAsFixed(1)}km, '
        'ETA: '
        '${(estimatedDurationSeconds / 60).round()}m',
      );

      return {
        'points': waypoints,
        'distance': totalDistance,
        'duration': estimatedDurationSeconds,
        'isFallback': true,
        'source': 'straight_line',
      };
    } catch (e) {
      debugPrint('[RouteService] Straight-line fallback failed: $e');

      return null;
    }
  }

  // ------------------------------------------------------------
  // GET ONLY ROUTE POLYLINE
  // ------------------------------------------------------------

  Future<List<LatLng>> getRoute(List<LatLng> waypoints) async {
    final Map<String, dynamic>? details = await getRouteDetails(waypoints);

    if (details == null) {
      return [];
    }

    final dynamic points = details['points'];

    if (points is List<LatLng>) {
      return points;
    }

    if (points is List) {
      return points.whereType<LatLng>().toList();
    }

    return [];
  }
}
