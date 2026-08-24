import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityLocation {
  const CommunityLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.attendanceRadiusMeters,
    this.placeId,
    this.updatedAt,
  });

  static const int defaultAttendanceRadiusMeters = 150;

  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? placeId;
  final int attendanceRadiusMeters;
  final DateTime? updatedAt;

  bool get isValid =>
      latitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude.isFinite &&
      longitude >= -180 &&
      longitude <= 180 &&
      formattedAddress.trim().isNotEmpty &&
      attendanceRadiusMeters >= 25 &&
      attendanceRadiusMeters <= 5000;

  factory CommunityLocation.fromMap(Map<String, dynamic> data) {
    double doubleValue(String field) {
      final value = data[field];

      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    String stringValue(String field) {
      final value = data[field];

      return value is String ? value.trim() : '';
    }

    DateTime? dateValue(String field) {
      final value = data[field];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      return null;
    }

    final radiusValue = data['attendanceRadiusMeters'];

    final radius = radiusValue is num
        ? radiusValue.toInt()
        : int.tryParse(radiusValue?.toString() ?? '') ??
              defaultAttendanceRadiusMeters;

    final placeIdValue = stringValue('placeId');

    return CommunityLocation(
      latitude: doubleValue('latitude'),
      longitude: doubleValue('longitude'),
      formattedAddress: stringValue('formattedAddress'),
      placeId: placeIdValue.isEmpty ? null : placeIdValue,
      attendanceRadiusMeters: radius.clamp(25, 5000),
      updatedAt: dateValue('updatedAt'),
    );
  }

  static CommunityLocation? tryFromMap(Map<String, dynamic> data) {
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final formattedAddress = data['formattedAddress'];
    final radius = data['attendanceRadiusMeters'];
    final placeId = data['placeId'];
    final updatedAt = data['updatedAt'];
    if (latitude is! num ||
        !latitude.toDouble().isFinite ||
        longitude is! num ||
        !longitude.toDouble().isFinite ||
        formattedAddress is! String ||
        formattedAddress.trim().isEmpty ||
        radius is! int ||
        radius < 25 ||
        radius > 5000 ||
        (placeId != null && placeId is! String) ||
        (updatedAt != null &&
            updatedAt is! Timestamp &&
            updatedAt is! DateTime)) {
      return null;
    }
    final parsed = CommunityLocation.fromMap(data);
    return parsed.isValid ? parsed : null;
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'formattedAddress': formattedAddress.trim(),
      'placeId': placeId?.trim(),
      'attendanceRadiusMeters': attendanceRadiusMeters,
    };
  }
}

class TenantConfig {
  const TenantConfig({
    required this.communityId,
    required this.name,
    required this.slug,
    required this.websitePath,
    required this.databaseId,
    required this.isActive,
    required this.createdBy,
    required this.locationConfigured,
    this.location,
    this.logoUrl,
    this.brandName,
    this.primaryColor,
    this.countryCode,
    this.createdAt,
    this.updatedAt,
  });

  static const defaultDatabaseId = '(default)';

  final String communityId;
  final String name;
  final String slug;
  final String websitePath;
  final String databaseId;
  final bool isActive;

  final String? logoUrl;
  final String? brandName;
  final String? primaryColor;
  final String? countryCode;

  final String createdBy;

  final bool locationConfigured;
  final CommunityLocation? location;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TenantConfig.fromMap(String communityId, Map<String, dynamic> data) {
    String stringValue(String field) {
      final value = data[field];

      return value is String ? value.trim() : '';
    }

    String? optionalString(String field) {
      final value = stringValue(field);

      return value.isEmpty ? null : value;
    }

    DateTime? dateValue(String field) {
      final value = data[field];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      return null;
    }

    final name = stringValue('name');

    final storedSlug = stringValue('slug');

    final slug = storedSlug.isEmpty ? slugify(name) : storedSlug;

    final storedWebsitePath = stringValue('websitePath');

    final storedDatabaseId = stringValue('databaseId');

    CommunityLocation? location;

    final rawLocation = data['location'];

    if (rawLocation is Map) {
      location = CommunityLocation.tryFromMap(
        Map<String, dynamic>.from(rawLocation),
      );
    }

    // Existing communities remain valid even
    // when location has never been configured.
    final locationConfigured =
        data['locationConfigured'] == true && location != null;

    return TenantConfig(
      communityId: communityId,
      name: name,
      slug: slug,
      websitePath: storedWebsitePath.isEmpty ? slug : storedWebsitePath,
      databaseId: storedDatabaseId.isEmpty
          ? defaultDatabaseId
          : storedDatabaseId,
      isActive: data['isActive'] == true,
      logoUrl: optionalString('logoUrl'),
      brandName: optionalString('brandName') ?? name,
      primaryColor: optionalString('primaryColor'),
      countryCode: _validCountryCode(optionalString('countryCode')),
      createdBy: stringValue('createdBy'),
      locationConfigured: locationConfigured,
      location: location,
      createdAt: dateValue('createdAt'),
      updatedAt: dateValue('updatedAt'),
    );
  }

  static String slugify(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String? _validCountryCode(String? value) {
    final code = value?.trim().toUpperCase();
    return code != null && RegExp(r'^[A-Z]{2}$').hasMatch(code) ? code : null;
  }
}
