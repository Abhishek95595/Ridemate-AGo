import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/vehicle_marker_service.dart';
import '../../../services/route_service.dart';

class GoogleMapScreen extends StatefulWidget {
  final String? vehicleType;
  const GoogleMapScreen({super.key, this.vehicleType});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  GoogleMapController? _mapController;
  final RouteService _routeService = RouteService();

  static const LatLng _defaultLocation = LatLng(28.6139, 77.2090);

  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  BitmapDescriptor? _carIcon;
  List<LatLng> _routePoints = [];

  bool _isLoadingLocation = false;
  bool _selectingPickup = true;

  @override
  void initState() {
    super.initState();
    VehicleMarkerService.instance.initMarkers().then((_) {
      if (mounted) setState(() {});
    });
    _loadCarIcon();
    _getCurrentLocation();
  }

  static String _getVehicleAssetPath(String? vehicleType) {
    final v = VehicleMarkerService.normalizeVehicleType(vehicleType);
    if (v == 'bike') {
      return 'assets/map_markers/bike.png';
    }
    return 'assets/map_markers/car.png';
  }

  Future<void> _loadCarIcon() async {
    final String assetPath = _getVehicleAssetPath(widget.vehicleType);
    try {
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(130, 130)),
        assetPath,
      );
      if (mounted) {
        setState(() {
          _carIcon = icon;
        });
      }
    } catch (_) {
      try {
        final ByteData data = await rootBundle.load(assetPath);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 260,
        );
        final ui.FrameInfo fi = await codec.getNextFrame();
        final ByteData? bytes = await fi.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (bytes != null && mounted) {
          setState(() {
            _carIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
          });
        }
      } catch (e) {
        debugPrint('Error loading vehicle asset icon: $e');
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Please enable location services.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission was denied.', isError: true);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final LatLng location = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentLocation = location;
        _pickupLocation ??= location;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
    } catch (error) {
      _showMessage('Unable to get current location: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      if (_selectingPickup) {
        _pickupLocation = position;
        _selectingPickup = false;
      } else {
        _destinationLocation = position;
      }
    });

    _updateMapCamera();
  }

  void _updateMapCamera() {
    if (_pickupLocation == null && _destinationLocation == null) return;

    if (_pickupLocation != null && _destinationLocation == null) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(_pickupLocation!));
      return;
    }

    if (_pickupLocation != null && _destinationLocation != null) {
      _fetchRoute();
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLocation!.latitude < _destinationLocation!.latitude
              ? _pickupLocation!.latitude
              : _destinationLocation!.latitude,
          _pickupLocation!.longitude < _destinationLocation!.longitude
              ? _pickupLocation!.longitude
              : _destinationLocation!.longitude,
        ),
        northeast: LatLng(
          _pickupLocation!.latitude > _destinationLocation!.latitude
              ? _pickupLocation!.latitude
              : _destinationLocation!.latitude,
          _pickupLocation!.longitude > _destinationLocation!.longitude
              ? _pickupLocation!.longitude
              : _destinationLocation!.longitude,
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    }
  }

  Future<void> _fetchRoute() async {
    if (_pickupLocation == null || _destinationLocation == null) return;
    final pts = await _routeService.getRoute([
      _pickupLocation!,
      _destinationLocation!,
    ]);
    if (mounted && pts.isNotEmpty) {
      setState(() {
        _routePoints = pts;
      });
    }
  }

  void _selectPickupMode() {
    setState(() => _selectingPickup = true);
    _showMessage('Tap on the map to select pickup.');
  }

  void _selectDestinationMode() {
    setState(() => _selectingPickup = false);
    _showMessage('Tap on the map to select destination.');
  }

  void _clearLocations() {
    setState(() {
      _pickupLocation = _currentLocation;
      _destinationLocation = null;
      _routePoints = [];
      _selectingPickup = true;
    });
  }

  void _confirmLocations() {
    if (_pickupLocation == null) {
      _showMessage('Please select a pickup location.', isError: true);
      return;
    }
    if (_destinationLocation == null) {
      _showMessage('Please select a destination.', isError: true);
      return;
    }

    Navigator.pop(context, {
      'pickupLatitude': _pickupLocation!.latitude,
      'pickupLongitude': _pickupLocation!.longitude,
      'destinationLatitude': _destinationLocation!.latitude,
      'destinationLongitude': _destinationLocation!.longitude,
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    if (_pickupLocation != null) {
      double heading = 0.0;
      if (_destinationLocation != null) {
        final b = Geolocator.bearingBetween(
          _pickupLocation!.latitude,
          _pickupLocation!.longitude,
          _destinationLocation!.latitude,
          _destinationLocation!.longitude,
        );
        heading = (b + 360) % 360;
      }
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          infoWindow: const InfoWindow(title: 'Pickup (Driver Start)'),
          rotation: heading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          icon:
              _carIcon ??
              VehicleMarkerService.instance.getMarkerIcon(widget.vehicleType),
        ),
      );
    }

    if (_destinationLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_pickupLocation == null || _destinationLocation == null) return {};

    final List<LatLng> pts = _routePoints.isNotEmpty
        ? _routePoints
        : [_pickupLocation!, _destinationLocation!];

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        width: 5,
        color: const Color(0xFF5B4CF0),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Ride Route',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _clearLocations,
            tooltip: 'Clear locations',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? _defaultLocation,
              zoom: 13,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      _selectingPickup
                          ? Icons.radio_button_checked
                          : Icons.location_on,
                      color: _selectingPickup
                          ? const Color(0xFF5B4CF0)
                          : Colors.redAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectingPickup
                            ? 'Tap the map to select pickup'
                            : 'Tap the map to select destination',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 185,
            child: FloatingActionButton.small(
              heroTag: 'currentLocation',
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              child: _isLoadingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectPickupMode,
                            icon: const Icon(Icons.radio_button_checked),
                            label: const Text('PICKUP'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDestinationMode,
                            icon: const Icon(Icons.location_on),
                            label: const Text('DESTINATION'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _confirmLocations,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B4CF0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'CONFIRM ROUTE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
