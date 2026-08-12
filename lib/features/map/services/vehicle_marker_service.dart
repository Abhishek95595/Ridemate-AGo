import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VehicleMarkerService {
  VehicleMarkerService._();
  static final VehicleMarkerService instance = VehicleMarkerService._();

  BitmapDescriptor? _carMarker;
  BitmapDescriptor? _bikeMarker;
  bool _isInitializing = false;

  BitmapDescriptor? get carMarker => _carMarker;
  BitmapDescriptor? get bikeMarker => _bikeMarker;

  /// Normalizes vehicle type string to either 'bike' or 'car'
  static String normalizeVehicleType(String? vehicleType) {
    final v = (vehicleType ?? '').trim().toLowerCase();
    if (v == 'bike' ||
        v.contains('bike') ||
        v.contains('motorcycle') ||
        v.contains('scooter') ||
        v.contains('scooty') ||
        v.contains('scoty') ||
        v.contains('2 wheeler') ||
        v.contains('two wheeler') ||
        v.contains('twowheeler') ||
        v == '2w' ||
        v == '2-wheeler') {
      return 'bike';
    }
    return 'car';
  }

  /// Load and cache car and bike marker assets once
  Future<void> initMarkers() async {
    if ((_carMarker != null && _bikeMarker != null) || _isInitializing) return;
    _isInitializing = true;

    try {
      _carMarker = await _loadAssetBitmap('assets/map_markers/car.png');
    } catch (e) {
      debugPrint('[VehicleMarkerService] Error loading car marker: $e');
    }

    try {
      _bikeMarker = await _loadAssetBitmap('assets/map_markers/bike.png');
    } catch (e) {
      debugPrint('[VehicleMarkerService] Error loading bike marker: $e');
    }

    _isInitializing = false;
  }

  Future<BitmapDescriptor> _loadAssetBitmap(String assetPath) async {
    try {
      return await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(120, 120)),
        assetPath,
      );
    } catch (_) {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 240,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? bytes = await fi.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    }
  }

  /// Returns the appropriate cached BitmapDescriptor for the vehicle type
  BitmapDescriptor getMarkerIcon(String? vehicleType) {
    final type = normalizeVehicleType(vehicleType);
    if (type == 'bike') {
      return _bikeMarker ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
    return _carMarker ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  }

  /// Computes shortest angular delta between current and target heading (in degrees).
  /// Handles wrap-around correctly (e.g., 359° -> 1° results in +2° delta instead of -358°).
  static double shortestHeadingDelta(double current, double target) {
    return (target - current + 540) % 360 - 180;
  }

  /// Evaluates whether a GPS heading update is valid and reliable.
  /// Ignores NaN, negative values, and jitter when speed is low or movement is negligible.
  static bool isValidHeading(double? heading) {
    if (heading == null) return false;
    return heading.isFinite && !heading.isNaN && heading >= 0 && heading <= 360;
  }
}
