import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a location with full address and coordinates.
class LocationModel {
  final String id;
  final String name;
  final String fullAddress;
  final String? secondaryAddress;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;

  const LocationModel({
    required this.id,
    required this.name,
    required this.fullAddress,
    this.secondaryAddress,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
  });

  LatLng? get latLng => (latitude != null && longitude != null)
      ? LatLng(latitude!, longitude!)
      : null;

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['place_id'] ?? json['osm_id']?.toString() ?? '',
      name: json['name'] ?? '',
      fullAddress: json['display_name'] ?? json['description'] ?? '',
      secondaryAddress: json['secondary_address'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      latitude: double.tryParse(json['lat']?.toString() ?? ''),
      longitude: double.tryParse(json['lon']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_id': id,
      'name': name,
      'display_name': fullAddress,
      'secondary_address': secondaryAddress,
      'city': city,
      'state': state,
      'country': country,
      'lat': latitude,
      'lon': longitude,
    };
  }

  LocationModel copyWith({
    String? name,
    String? fullAddress,
    String? secondaryAddress,
    double? latitude,
    double? longitude,
  }) {
    return LocationModel(
      id: id,
      name: name ?? this.name,
      fullAddress: fullAddress ?? this.fullAddress,
      secondaryAddress: secondaryAddress ?? this.secondaryAddress,
      city: city,
      state: state,
      country: country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
