import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/passenger_card.dart';
import '../../../core/widgets/rate_driver_bottom_sheet.dart';
import '../../../services/live_location_service.dart';
import '../../../services/route_service.dart';
import '../../../services/sos_service.dart';
import '../../offer_ride/models/ride_model.dart';
import '../models/booking_model.dart';
import '../../../services/booking_service.dart';

import '../../chat/screens/chat_screen.dart';

import '../../map/services/vehicle_marker_service.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;

  final LiveLocationService _locationService = LiveLocationService.instance;

  final RouteService _routeService = RouteService();

  final ValueNotifier<LatLng?> _driverPosNotifier = ValueNotifier<LatLng?>(
    null,
  );

  final ValueNotifier<List<LatLng>> _routePointsNotifier =
      ValueNotifier<List<LatLng>>(<LatLng>[]);

  final ValueNotifier<double> _durationNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> _distanceNotifier = ValueNotifier<double>(0);

  final ValueNotifier<String> _statusNotifier = ValueNotifier<String>(
    'pending',
  );

  final ValueNotifier<bool> _sosActiveNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _driverHeadingNotifier = ValueNotifier<double>(
    0.0,
  );

  StreamSubscription<dynamic>? _locationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _bookingSubscription;

  LatLng? _pickupPos;
  LatLng? _dropPos;

  BitmapDescriptor? _startCarIcon;
  BitmapDescriptor? _driverCarIcon;

  bool _isFetchingRoute = false;
  bool _routeRefreshPending = false;
  bool _isSyncing = true;
  bool _completionDialogShown = false;

  String _rideId = '';
  String _vehicleType = 'car';
  String _driverId = '';
  double? _sosX;
  double? _sosY;
  AnimationController? _markerAnimationController;
  DateTime? _lastLocationTimestamp;

  @override
  void initState() {
    super.initState();
    VehicleMarkerService.instance.initMarkers().then((_) {
      if (mounted && _vehicleType.isNotEmpty) {
        _loadCarMarkerIcons(_vehicleType);
      }
    });
    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadCarMarkerIcons();
    _startBookingListener();
  }

  String? _loadedVehicleType;

  Future<void> _loadCarMarkerIcons([String? vehicleType]) async {
    final vType = (vehicleType ?? '').trim();
    if (_startCarIcon != null &&
        _loadedVehicleType == vType &&
        vType.isNotEmpty) {
      return;
    }
    try {
      final carAssetIcon = await _getVehicleAssetBitmap(vType);
      if (mounted) {
        setState(() {
          _loadedVehicleType = vType;
          _startCarIcon = carAssetIcon;
          _driverCarIcon = carAssetIcon;
        });
      }
    } catch (e) {
      debugPrint('Error loading vehicle asset marker icon: $e');
    }
  }

  static String _getVehicleAssetPath(String? vehicleType) {
    final v = (vehicleType ?? '').trim().toLowerCase();
    if (v.contains('bike') ||
        v.contains('motorcycle') ||
        v.contains('scooter') ||
        v.contains('scooty') ||
        v.contains('scoty') ||
        v.contains('2 wheeler') ||
        v.contains('two wheeler') ||
        v.contains('twowheeler') ||
        v == '2w' ||
        v == '2-wheeler') {
      return 'assets/map_markers/bike.png';
    }
    return 'assets/map_markers/car.png';
  }

  static Future<BitmapDescriptor> _getVehicleAssetBitmap([
    String? vehicleType,
  ]) async {
    final String assetPath = _getVehicleAssetPath(vehicleType);
    try {
      return await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(130, 130)),
        assetPath,
      );
    } catch (_) {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 260,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ByteData? bytes = await fi.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    }
  }

  @override
  void dispose() {
    _markerAnimationController?.dispose();
    _locationSubscription?.cancel();
    _bookingSubscription?.cancel();
    _statusNotifier.dispose();
    _driverPosNotifier.dispose();
    _routePointsNotifier.dispose();
    _durationNotifier.dispose();
    _distanceNotifier.dispose();
    _sosActiveNotifier.dispose();
    _driverHeadingNotifier.dispose();
    super.dispose();
  }

  void _handleSOSTrigger(BookingModel booking) async {
    final contact = await SosService.instance.fetchEmergencyContact();
    if (!mounted) return;

    if (contact == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please set an emergency contact in your profile first.",
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bool? confirm = await _showSOSConfirmationDialog(contact['name']!);
    if (confirm != true || !mounted) return;

    try {
      // Ensure permissions are granted before getting location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permissions are denied.");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied.");
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _sosActiveNotifier.value = true;
      await SosService.instance.triggerSOS(booking, pos);
      await SosService.instance.sendSOSMessage(contact['phone']!, booking, pos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("SOS failed: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<bool?> _showSOSConfirmationDialog(String contactName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Mint Siren Icon Container
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F7F5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emergency_outlined,
                        size: 38,
                        color: Color(0xFF0D8379),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D8379),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "SOS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "Trigger SOS?",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D8379),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Are you sure you want to trigger SOS? This will alert $contactName and share your live location.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  color: const Color(0xFF475569),
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF0D8379),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "CANCEL",
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D8379),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D8379),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "YES, TRIGGER SOS",
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isValidLatLng(LatLng? point) {
    if (point == null) {
      return false;
    }

    final double latitude = point.latitude;
    final double longitude = point.longitude;

    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  LatLng? _createValidLatLng(dynamic latitudeValue, dynamic longitudeValue) {
    if (latitudeValue is! num || longitudeValue is! num) {
      return null;
    }

    final LatLng point = LatLng(
      latitudeValue.toDouble(),
      longitudeValue.toDouble(),
    );

    return _isValidLatLng(point) ? point : null;
  }

  List<LatLng> _getValidMapPoints() {
    final List<LatLng> points = <LatLng>[];

    void addPoint(LatLng? point) {
      if (_isValidLatLng(point)) {
        points.add(point!);
      }
    }

    addPoint(_driverPosNotifier.value);

    final String status = _statusNotifier.value;
    if (status == 'started') {
      addPoint(_dropPos);
    } else {
      addPoint(_pickupPos);
    }

    for (final LatLng point in _routePointsNotifier.value) {
      addPoint(point);
    }

    return points;
  }

  void _fitMapSafely() {
    if (!mounted || _mapController == null) {
      return;
    }

    final List<LatLng> points = _getValidMapPoints();

    if (points.isEmpty) return;

    try {
      if (points.length == 1) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 15),
        );
        return;
      }

      double minLat = points
          .map((p) => p.latitude)
          .reduce((a, b) => a < b ? a : b);
      double maxLat = points
          .map((p) => p.latitude)
          .reduce((a, b) => a > b ? a : b);
      double minLng = points
          .map((p) => p.longitude)
          .reduce((a, b) => a < b ? a : b);
      double maxLng = points
          .map((p) => p.longitude)
          .reduce((a, b) => a > b ? a : b);

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (e) {
      debugPrint('[JourneyMap] Camera animate bounds error: $e');
    }
  }

  void _startBookingListener() {
    _bookingSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) async {
            if (!mounted || !snapshot.exists) {
              return;
            }

            final BookingModel booking = BookingModel.fromDocument(snapshot);

            final String oldStatus = _statusNotifier.value;
            _statusNotifier.value = booking.status;
            if (oldStatus != booking.status) {
              unawaited(_updateRoute());
            }
            final String newBookingVType = booking.normalizedVehicleType;
            if (_vehicleType != newBookingVType) {
              if (mounted) {
                setState(() {
                  _vehicleType = newBookingVType;
                });
              }
            }
            if (booking.driverId.isNotEmpty) {
              _driverId = booking.driverId;
            }

            final String bookingVehicle =
                (booking.driverDetails['vehicle'] ?? '').toString();
            if (bookingVehicle.isNotEmpty) {
              _loadCarMarkerIcons(bookingVehicle);
            }

            if (_rideId != booking.rideId) {
              _rideId = booking.rideId;

              _startLocationListener(_rideId);

              await _fetchRideDetails(booking.rideId);
            }

            _fitMapSafely();

            if (booking.status == 'completed' &&
                mounted &&
                !_completionDialogShown) {
              _completionDialogShown = true;

              // Automatically show review bottom sheet when ride completes
              final bool isRated = snapshot.data()?['isRated'] ?? false;
              if (!isRated) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => RateDriverBottomSheet(
                        rideId: booking.rideId,
                        bookingId: booking.id,
                        driverId: booking.driverId,
                        driverName: (booking.driverDetails['name'] ?? 'Driver')
                            .toString(),
                      ),
                    );
                  }
                });
              }
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Booking listener error: $error');

            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  Future<void> _fetchRideDetails(String rideId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await FirebaseFirestore.instance
              .collection('rides')
              .doc(rideId)
              .get();

      if (!mounted) {
        return;
      }

      if (!document.exists || document.data() == null) {
        setState(() {
          _isSyncing = false;
        });

        return;
      }

      final RideModel ride = RideModel.fromMap(document.data()!, document.id);
      final String newRideVType = ride.normalizedVehicleType;
      if (_vehicleType != newRideVType) {
        if (mounted) {
          setState(() {
            _vehicleType = newRideVType;
          });
        }
      }
      if (_driverId.isEmpty && ride.driverId.isNotEmpty) {
        _driverId = ride.driverId;
      }
      if (ride.vehicle.isNotEmpty) {
        _loadCarMarkerIcons(ride.vehicle);
      }

      final LatLng? pickup = _createValidLatLng(ride.pickupLat, ride.pickupLng);

      final LatLng? destination = _createValidLatLng(
        ride.destinationLat,
        ride.destinationLng,
      );

      setState(() {
        _pickupPos = pickup;
        _dropPos = destination;
        _isSyncing = false;
      });

      await _updateRoute();
      _fitMapSafely();
    } catch (error, stackTrace) {
      debugPrint('Could not load ride details: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _startLocationListener(String rideId) {
    _locationSubscription?.cancel();

    _locationSubscription = _locationService
        .watchLiveLocation(rideId)
        .listen(
          (dynamic locationData) {
            if (!mounted || locationData == null || locationData is! Map) {
              return;
            }

            final dynamic rawTs =
                locationData['timestamp'] ??
                locationData['recordedAt'] ??
                locationData['updatedAt'];
            if (rawTs is Timestamp) {
              final DateTime updateTime = rawTs.toDate();
              if (_lastLocationTimestamp != null &&
                  updateTime.isBefore(_lastLocationTimestamp!)) {
                debugPrint('Ignored out-of-order stale GPS update.');
                return;
              }
              _lastLocationTimestamp = updateTime;
            }

            final LatLng? newPosition = _createValidLatLng(
              locationData['latitude'],
              locationData['longitude'],
            );

            if (newPosition == null) return;

            final LatLng? oldPosition = _driverPosNotifier.value;
            final double oldHeading = _driverHeadingNotifier.value;

            final dynamic rawHeading =
                locationData['heading'] ?? locationData['bearing'];
            final double speed =
                (locationData['speed'] as num?)?.toDouble() ?? 0.0;

            double targetHeading = oldHeading;

            if (oldPosition != null) {
              final double distanceMoved = Geolocator.distanceBetween(
                oldPosition.latitude,
                oldPosition.longitude,
                newPosition.latitude,
                newPosition.longitude,
              );

              if (distanceMoved < 1.5 || speed < 0.5) {
                targetHeading = oldHeading;
              } else if (VehicleMarkerService.isValidHeading(
                rawHeading?.toDouble(),
              )) {
                targetHeading = rawHeading.toDouble();
              } else if (distanceMoved >= 2.0) {
                targetHeading =
                    (Geolocator.bearingBetween(
                          oldPosition.latitude,
                          oldPosition.longitude,
                          newPosition.latitude,
                          newPosition.longitude,
                        ) +
                        360) %
                    360;
              }
            } else {
              if (VehicleMarkerService.isValidHeading(rawHeading?.toDouble())) {
                targetHeading = rawHeading.toDouble();
              }
            }

            if (oldPosition == null) {
              _driverPosNotifier.value = newPosition;
              _driverHeadingNotifier.value = targetHeading;
              unawaited(_updateRoute());
              _fitMapSafely();
              return;
            }

            final LatLng startPos = oldPosition;
            final LatLng endPos = newPosition;
            final double startHeading = oldHeading;
            final double headingDelta =
                VehicleMarkerService.shortestHeadingDelta(
                  startHeading,
                  targetHeading,
                );

            _markerAnimationController?.stop();
            _markerAnimationController?.reset();

            void animationListener() {
              if (!mounted) return;
              final double t = _markerAnimationController?.value ?? 1.0;
              final double curLat =
                  startPos.latitude + (endPos.latitude - startPos.latitude) * t;
              final double curLng =
                  startPos.longitude +
                  (endPos.longitude - startPos.longitude) * t;
              final double curHeading =
                  (startHeading + headingDelta * t + 360) % 360;

              _driverPosNotifier.value = LatLng(curLat, curLng);
              _driverHeadingNotifier.value = curHeading;
            }

            _markerAnimationController?.addListener(animationListener);
            _markerAnimationController?.forward(from: 0.0).then((_) {
              if (mounted) {
                unawaited(_updateRoute());
                _fitMapSafely();
              }
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Position stream error: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
          cancelOnError: false,
        );
  }

  Future<void> _updateRoute() async {
    final LatLng? driverPosition = _driverPosNotifier.value;
    final String status = _statusNotifier.value;

    LatLng? startPos;
    LatLng? targetPos;

    if (_isValidLatLng(driverPosition)) {
      startPos = driverPosition;
      targetPos = status == 'started' ? _dropPos : _pickupPos;
    }

    if (!_isValidLatLng(startPos) || !_isValidLatLng(targetPos)) {
      // Fallback: draw route from Pickup (Point A) to Destination (Point B)
      if (_isValidLatLng(_pickupPos) && _isValidLatLng(_dropPos)) {
        startPos = _pickupPos;
        targetPos = _dropPos;
      }
    }

    if (!_isValidLatLng(startPos) || !_isValidLatLng(targetPos)) {
      debugPrint('Route skipped: start or target location is unavailable.');
      return;
    }

    if (_isFetchingRoute) {
      _routeRefreshPending = true;
      return;
    }

    _isFetchingRoute = true;

    try {
      debugPrint(
        'Route request: '
        'start=${startPos!.latitude},${startPos.longitude} | '
        'target=${targetPos!.latitude},${targetPos.longitude} | '
        'status=$status',
      );

      final Map<String, dynamic>? details = await _routeService.getRouteDetails(
        <LatLng>[startPos, targetPos],
      );

      if (!mounted) {
        return;
      }

      if (details == null) {
        debugPrint('Route service returned no route details.');
        return;
      }

      final dynamic rawPoints = details['points'];
      final List<LatLng> validRoutePoints = <LatLng>[];

      if (rawPoints is List) {
        for (final dynamic value in rawPoints) {
          if (value is LatLng && _isValidLatLng(value)) {
            validRoutePoints.add(value);
          }
        }
      }

      if (validRoutePoints.length < 2) {
        debugPrint(
          'Route ignored because fewer than 2 valid points were returned.',
        );
        return;
      }

      _routePointsNotifier.value = validRoutePoints;

      final dynamic rawDuration = details['duration'];
      _durationNotifier.value = rawDuration is num ? rawDuration.toDouble() : 0;

      final dynamic rawDistance = details['distance'];
      _distanceNotifier.value = rawDistance is num ? rawDistance.toDouble() : 0;

      debugPrint('Road route loaded: ${validRoutePoints.length} points.');

      _fitMapSafely();
    } catch (error, stackTrace) {
      debugPrint('Route update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isFetchingRoute = false;

      if (_routeRefreshPending && mounted) {
        _routeRefreshPending = false;
        unawaited(_updateRoute());
      }
    }
  }

  void _confirmCancelRide(BookingModel booking) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1B1D24) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Cancel Ride?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF071B3A),
            ),
          ),
          content: Text(
            'Are you sure to cancel the ride?',
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : const Color(0xFF65707D),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'NO',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await BookingService().cancelBooking(booking);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ride cancelled successfully.'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel: $error')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'YES, CANCEL',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _callPerson(String phone) async {
    final String cleanPhone = phone.trim();

    if (cleanPhone.isEmpty) {
      return;
    }

    final Uri uri = Uri(scheme: 'tel', path: cleanPhone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isSyncing) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF111318) : Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF14D8C4)),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final BookingModel booking = BookingModel.fromDocument(
                snapshot.data!,
              );

              if (booking.status == 'payment_pending' &&
                  booking.paymentStatus != 'verified_by_driver') {
                return _buildQrPaymentScreen(booking);
              }

              if (booking.status == 'completed') {
                return _buildRideCompletedSuccess(booking);
              }

              return Stack(
                children: <Widget>[
                  Positioned.fill(child: _buildMap()),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _statusNotifier,
                    builder:
                        (BuildContext context, String status, Widget? child) {
                          if (status != 'accepted' &&
                              status != 'started' &&
                              status != 'arrived') {
                            return const SizedBox.shrink();
                          }

                          String text = 'Journey in Progress';

                          if (status == 'accepted') {
                            text = 'Driver Accepted Ride';
                          } else if (status == 'arrived') {
                            text = 'Driver has Arrived';
                          }

                          return Positioned(
                            top: 100,
                            left: 20,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF332A26,
                                ).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    text,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                  ),
                  _buildWaitingForRideToStartOverlay(),
                  _buildWaitingForLocationOverlay(),

                  // SOS Active Banner
                  ValueListenableBuilder<bool>(
                    valueListenable: _sosActiveNotifier,
                    builder: (context, isActive, _) {
                      if (!isActive) return const SizedBox.shrink();
                      return Positioned(
                        top: 100,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  "SOS ACTIVE - SHARING LIVE LOCATION",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final contact = await SosService.instance
                                      .fetchEmergencyContact();
                                  if (contact != null) {
                                    await SosService.instance
                                        .callEmergencyContact(
                                          contact['phone']!,
                                        );
                                  }
                                },
                                icon: const Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  _sosActiveNotifier.value = false;
                                  SosService.instance.stopSOS();
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Movable Floating SOS Button
                  Builder(
                    builder: (context) {
                      final screenSize = MediaQuery.of(context).size;
                      final double defaultX = screenSize.width - 85;
                      final double defaultY = screenSize.height - 380;
                      final double posX = (_sosX ?? defaultX).clamp(
                        10.0,
                        screenSize.width - 75.0,
                      );
                      final double posY = (_sosY ?? defaultY).clamp(
                        60.0,
                        screenSize.height - 120.0,
                      );

                      return Positioned(
                        left: posX,
                        top: posY,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _sosActiveNotifier,
                          builder: (context, isActive, _) {
                            return GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _sosX = (posX + details.delta.dx).clamp(
                                    10.0,
                                    screenSize.width - 75.0,
                                  );
                                  _sosY = (posY + details.delta.dy).clamp(
                                    60.0,
                                    screenSize.height - 120.0,
                                  );
                                });
                              },
                              onTap: () => _handleSOSTrigger(booking),
                              onLongPress: () => _handleSOSTrigger(booking),
                              child: Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.red : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    isActive
                                        ? Icons.emergency_rounded
                                        : Icons.sos_rounded,
                                    color: isActive ? Colors.white : Colors.red,
                                    size: 30,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  DraggableScrollableSheet(
                    initialChildSize: 0.35,
                    minChildSize: 0.15,
                    maxChildSize: 0.9,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B1D24)
                              : Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              Center(
                                child: Container(
                                  width: 50,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  "Swipe up for details",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildBottomPanelContent(booking, isDark),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
      ),
    );
  }

  Widget _buildWaitingForRideToStartOverlay() {
    return const SizedBox.shrink();
  }

  Widget _buildWaitingForLocationOverlay() {
    return ValueListenableBuilder<String>(
      valueListenable: _statusNotifier,
      builder: (BuildContext context, String status, Widget? child) {
        if (status != 'started') {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<LatLng?>(
          valueListenable: _driverPosNotifier,
          builder:
              (BuildContext context, LatLng? driverPosition, Widget? child) {
                return ValueListenableBuilder<List<LatLng>>(
                  valueListenable: _routePointsNotifier,
                  builder:
                      (
                        BuildContext context,
                        List<LatLng> routePoints,
                        Widget? child,
                      ) {
                        if (_getValidMapPoints().isNotEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Positioned(
                          top: 155,
                          left: 24,
                          right: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Waiting for live location...',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                );
              },
        );
      },
    );
  }

  double _calculateRouteHeading(LatLng pos, List<LatLng> points) {
    if (points.length < 2) return 0.0;

    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < points.length; i++) {
      final double dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    int nextIndex = closestIndex + 1;
    if (nextIndex >= points.length) {
      nextIndex = closestIndex;
      closestIndex = closestIndex > 0 ? closestIndex - 1 : 0;
    }

    if (closestIndex == nextIndex) return 0.0;

    final LatLng p1 = points[closestIndex];
    final LatLng p2 = points[nextIndex];

    final double b = Geolocator.bearingBetween(
      p1.latitude,
      p1.longitude,
      p2.latitude,
      p2.longitude,
    );
    return (b + 360) % 360;
  }

  Widget _buildMapPlaceholder(bool isDark) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? const Color(0xFF101218) : const Color(0xFFF1F5F9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFF14D8C4).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.map_rounded,
                    size: 38,
                    color: Color(0xFF14D8C4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Real time map will be shown here",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF14D8C4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Waiting for ride to start...",
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: _statusNotifier,
      builder: (context, status, _) {
        if (status != 'started') {
          return _buildMapPlaceholder(isDark);
        }

        return ValueListenableBuilder<LatLng?>(
          valueListenable: _driverPosNotifier,
          builder: (context, driverPos, _) {
            return ValueListenableBuilder<double>(
              valueListenable: _driverHeadingNotifier,
              builder: (context, driverHeading, _) {
                return ValueListenableBuilder<List<LatLng>>(
                  valueListenable: _routePointsNotifier,
                  builder: (context, routePoints, _) {
                    LatLng initialLocation = const LatLng(
                      28.5922338,
                      77.4365888,
                    );
                    if (_isValidLatLng(driverPos)) {
                      initialLocation = driverPos!;
                    } else if (_isValidLatLng(_pickupPos)) {
                      initialLocation = _pickupPos!;
                    } else if (_isValidLatLng(_dropPos)) {
                      initialLocation = _dropPos!;
                    }

                    final double pickupRotation = _isValidLatLng(_pickupPos)
                        ? _calculateRouteHeading(_pickupPos!, routePoints)
                        : 0.0;
                    final double currentCarRotation = (driverHeading != 0.0)
                        ? driverHeading
                        : (_isValidLatLng(driverPos)
                              ? _calculateRouteHeading(driverPos!, routePoints)
                              : pickupRotation);

                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialLocation,
                        zoom: 14,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) _fitMapSafely();
                        });
                      },
                      markers: {
                        if (_isValidLatLng(_pickupPos))
                          Marker(
                            markerId: MarkerId(
                              'pickup_${_rideId.isNotEmpty ? _rideId : widget.bookingId}',
                            ),
                            position: _pickupPos!,
                            infoWindow: const InfoWindow(
                              title: 'Rider Pickup Location',
                            ),
                            anchor: const Offset(0.5, 1.0),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            ),
                          ),
                        if (_isValidLatLng(_dropPos))
                          Marker(
                            markerId: MarkerId(
                              'drop_${_rideId.isNotEmpty ? _rideId : widget.bookingId}',
                            ),
                            position: _dropPos!,
                            infoWindow: const InfoWindow(title: 'Destination'),
                            anchor: const Offset(0.5, 1.0),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed,
                            ),
                          ),
                        if (_isValidLatLng(driverPos))
                          Marker(
                            markerId: MarkerId(
                              'driver_${_driverId.isNotEmpty ? _driverId : widget.bookingId}',
                            ),
                            position: driverPos!,
                            infoWindow: const InfoWindow(
                              title: 'Driver Live Position',
                            ),
                            rotation: currentCarRotation,
                            anchor: const Offset(0.5, 0.5),
                            flat: true,
                            icon:
                                _driverCarIcon ??
                                VehicleMarkerService.instance.getMarkerIcon(
                                  _vehicleType,
                                ),
                          ),
                      },
                      polylines: {
                        if (routePoints.isNotEmpty)
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: routePoints,
                            color: const Color(0xFF14D8C4),
                            width: 5,
                          ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomPanelContent(BookingModel booking, bool isDark) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(booking.driverId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> driverData =
                snapshot.data?.data() ??
                Map<String, dynamic>.from(booking.driverDetails);

            final dynamic storedAvatar = driverData['avatarIndex'];

            final int? driverAvatarIndex = storedAvatar is int
                ? storedAvatar
                : int.tryParse(storedAvatar?.toString() ?? '');

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            driverData['vehicleNumber']?.toString() ??
                                'DL 00 XX 0000',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            '${driverData['vehicleColor'] ?? ''} '
                            '${driverData['vehicleModel'] ?? driverData['vehicle'] ?? 'Vehicle'}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Text(
                                driverData['name']?.toString() ?? 'Driver',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              Text(
                                ' ${(() {
                                  final r = driverData['rating'] ?? driverData['averageRating'];
                                  double val = 4.8;
                                  if (r is num) {
                                    val = r.toDouble();
                                  } else if (r != null) {
                                    val = double.tryParse(r.toString()) ?? 4.8;
                                  }
                                  return val.toStringAsFixed(1);
                                })()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AppAvatar(
                      avatarIndex: driverAvatarIndex,
                      photoUrl: driverData['photoUrl']?.toString(),
                      size: 70,
                      borderColor: const Color(0xFF14D8C4),
                      borderWidth: 1.2,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const SizedBox(height: 30),
                _buildPassengersList(booking, isDark),
                const SizedBox(height: 30),
                // Real-time Stats Row (Distance, ETA, Real Fare calculated per seat)
                ValueListenableBuilder<double>(
                  valueListenable: _distanceNotifier,
                  builder: (context, distanceMeters, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: _durationNotifier,
                      builder: (context, durationSeconds, _) {
                        double realDistKm = distanceMeters / 1000;
                        if (realDistKm <= 0 &&
                            _isValidLatLng(_pickupPos) &&
                            _isValidLatLng(_dropPos)) {
                          realDistKm =
                              Geolocator.distanceBetween(
                                _pickupPos!.latitude,
                                _pickupPos!.longitude,
                                _dropPos!.latitude,
                                _dropPos!.longitude,
                              ) /
                              1000;
                        }

                        int realEtaMins = (durationSeconds / 60).round();
                        if (realEtaMins <= 0 && realDistKm > 0) {
                          realEtaMins = (realDistKm * 1000 / 8.33 / 60).round();
                          if (realEtaMins < 1) realEtaMins = 1;
                        }

                        final int seats = booking.seatsBooked > 0
                            ? booking.seatsBooked
                            : 1;
                        final double totalFare = (booking.price * seats)
                            .toDouble();

                        return Row(
                          children: [
                            Expanded(
                              child: _buildMiniStat(
                                Icons.edit_road_rounded,
                                realDistKm > 0
                                    ? '${realDistKm.toStringAsFixed(1)} km'
                                    : 'Calculating...',
                                'Distance',
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMiniStat(
                                Icons.access_time_rounded,
                                realEtaMins > 0
                                    ? '$realEtaMins min'
                                    : 'Calculating...',
                                'ETA',
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMiniStat(
                                Icons.account_balance_wallet_rounded,
                                '₹${totalFare.toStringAsFixed(1)}',
                                'Fare',
                                isDark,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 25),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .doc(booking.id)
                      .snapshots(),
                  builder: (context, bookingSnap) {
                    final bookingData = bookingSnap.data?.data() ?? {};
                    if (booking.status == 'completed' &&
                        !(bookingData['isRated'] ?? false)) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => RateDriverBottomSheet(
                                  rideId: booking.rideId,
                                  bookingId: booking.id,
                                  driverId: booking.driverId,
                                  driverName: driverData['name'] ?? 'Driver',
                                ),
                              );
                            },
                            icon: const Icon(Icons.star_rounded),
                            label: const Text(
                              'RATE DRIVER',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () => _confirmCancelRide(booking),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel Ride',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14D8C4).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF14D8C4).withValues(alpha: 0.2),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF14D8C4),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                bookingId: booking.id,
                                otherUserName:
                                    driverData['name']?.toString() ?? 'Driver',
                                otherUserPhone:
                                    driverData['phone']?.toString() ?? '',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14D8C4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.call, color: Colors.white),
                        onPressed: () {
                          _callPerson(driverData['phone']?.toString() ?? '');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            );
          },
    );
  }

  Widget _buildMiniStat(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1B1D24)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengersList(BookingModel booking, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passengers',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF08234C),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: booking.rideId.trim().isNotEmpty
              ? FirebaseFirestore.instance
                    .collection('bookings')
                    .where('rideId', isEqualTo: booking.rideId)
                    .snapshots()
              : null,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: LinearProgressIndicator());
            }

            final rawDocs = snapshot.data?.docs ?? [];
            final docs = rawDocs.where((doc) {
              final status = (doc.data()['status'] ?? '').toString();
              return status != 'cancelled' && status != 'rejected';
            }).toList();

            if (docs.isEmpty) {
              return PassengerCard(
                passengerId: booking.passengerId,
                passengerName: booking.passengerName,
                photoUrl: null,
                avatarIndex: null,
                seatsBooked: booking.seatsBooked,
                driverId: booking.driverId,
                isDark: isDark,
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final data = docs[index].data();

                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(data['passengerId'])
                      .get(),
                  builder: (context, userSnap) {
                    final userData = userSnap.data?.data() ?? {};
                    return PassengerCard(
                      passengerId: data['passengerId'] ?? '',
                      passengerName: data['passengerName'] ?? 'Rider',
                      photoUrl: userData['photoUrl'],
                      avatarIndex: userData['avatarIndex'],
                      seatsBooked: data['seatsBooked'] ?? 1,
                      driverId: booking.driverId,
                      isDark: isDark,
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQrPaymentScreen(BookingModel booking) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final BookingService service = BookingService();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111318)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Ride Payment",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(booking.driverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final driverData = snapshot.data!.data() ?? {};
          final String upiId = driverData['upiId']?.toString() ?? '';
          final String driverName = driverData['name'] ?? 'Driver';
          final double totalPaymentAmount = booking.totalPrice.toDouble();

          final String upiUri =
              "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(driverName)}&am=${totalPaymentAmount.toStringAsFixed(2)}&cu=INR&tn=Ride%20Payment";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                _buildPaymentHero(driverData, booking, isDark),
                const SizedBox(height: 35),

                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B1D24) : Colors.white,
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (upiId.isNotEmpty)
                        QrImageView(
                          data: upiUri,
                          version: QrVersions.auto,
                          size: 240.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: Color(0xFF14B8A6),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Color(0xFF14B8A6),
                          ),
                        )
                      else
                        const Text("Driver has not set up UPI ID"),

                      const SizedBox(height: 25),
                      Text(
                        "UPI ID: $upiId",
                        style: GoogleFonts.robotoMono(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: upiId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("UPI ID Copied!")),
                          );
                        },
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: Color(0xFF14B8A6),
                        ),
                        label: Text(
                          "Copy UPI ID",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF14B8A6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Text(
                  "Scan this QR using any UPI app and complete the payment.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 62,
                  child: ElevatedButton(
                    onPressed: booking.paymentStatus == 'submitted_by_passenger'
                        ? null
                        : () async {
                            await service.submitPayment(
                              bookingId: booking.id,
                              passengerId:
                                  FirebaseAuth.instance.currentUser!.uid,
                              amount: booking.totalPrice.toDouble(),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      booking.paymentStatus == 'submitted_by_passenger'
                          ? "AWAITING VERIFICATION..."
                          : "I HAVE COMPLETED PAYMENT",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                if (booking.paymentStatus == 'submitted_by_passenger')
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Text(
                      "Please wait for the driver to verify your payment.",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentHero(
    Map<String, dynamic> driver,
    BookingModel booking,
    bool isDark,
  ) {
    final dynamic storedAvatar = driver['avatarIndex'];
    final int? avatarIndex = storedAvatar is int
        ? storedAvatar
        : int.tryParse(storedAvatar?.toString() ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          AppAvatar(
            avatarIndex: avatarIndex,
            photoUrl: driver['photoUrl']?.toString(),
            size: 65,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver['name'] ?? 'Driver',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  driver['vehicleNumber'] ?? 'Vehicle',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                booking.seatsBooked > 1
                    ? "Total (${booking.seatsBooked} seats)"
                    : "Fare",
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                "₹${booking.totalPrice.toStringAsFixed(0)}",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              if (booking.seatsBooked > 1)
                Text(
                  "₹${booking.price}/seat",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRideCompletedSuccess(BookingModel booking) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111318) : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Ride Completed! 🏁",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF08234C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your journey from ${booking.pickup} to ${booking.destination} is successfully completed.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Only show manual rate button if not already rated
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .doc(booking.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() ?? {};
                  final bool alreadyRated = data['isRated'] ?? false;

                  if (alreadyRated) {
                    return const SizedBox.shrink();
                  }

                  return SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => RateDriverBottomSheet(
                            rideId: booking.rideId,
                            bookingId: booking.id,
                            driverId: booking.driverId,
                            driverName:
                                (booking.driverDetails['name'] ?? 'Driver')
                                    .toString(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_rounded),
                      label: Text(
                        "RATE YOUR JOURNEY",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
