import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityCommunityLocation {
  const SecurityCommunityLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.attendanceRadiusMeters,
    this.placeId,
  });
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final int attendanceRadiusMeters;
  final String? placeId;

  static SecurityCommunityLocation? tryParse(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final address = data['formattedAddress'];
    final radius = data['attendanceRadiusMeters'];
    if (latitude is! num ||
        longitude is! num ||
        address is! String ||
        address.trim().isEmpty ||
        radius is! int ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        radius < 25 ||
        radius > 5000) {
      return null;
    }
    return SecurityCommunityLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      formattedAddress: address.trim(),
      attendanceRadiusMeters: radius,
      placeId: data['placeId'] is String ? data['placeId'] as String : null,
    );
  }
}

class SecurityCommunityModel {
  const SecurityCommunityModel({
    required this.id,
    required this.isActive,
    required this.locationConfigured,
    this.location,
  });
  final String id;
  final bool isActive;
  final bool locationConfigured;
  final SecurityCommunityLocation? location;

  factory SecurityCommunityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final location = SecurityCommunityLocation.tryParse(data['location']);
    return SecurityCommunityModel(
      id: snapshot.id,
      isActive: data['isActive'] == true,
      locationConfigured:
          data['locationConfigured'] == true && location != null,
      location: location,
    );
  }
}
