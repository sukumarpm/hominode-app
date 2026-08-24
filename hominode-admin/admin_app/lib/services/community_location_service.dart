import 'package:geolocator/geolocator.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CommunityLocationSearchResult {
  const CommunityLocationSearchResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.placeId,
  });
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? placeId;
}

class CommunityLocationSuggestion {
  const CommunityLocationSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.displayText,
  });
  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String displayText;
}

class CommunityLocationException implements Exception {
  const CommunityLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class CommunityLocationGateway {
  Future<List<CommunityLocationSuggestion>> search(
    String query, {
    required String sessionToken,
    String? countryCode,
  });
  Future<CommunityLocationSearchResult> resolvePlace(
    String placeId, {
    required String sessionToken,
  });
  Future<CommunityLocationSearchResult?> reverseGeocode(
    double latitude,
    double longitude,
  );
  Future<Position> getCurrentPosition();
}

class CommunityLocationService implements CommunityLocationGateway {
  CommunityLocationService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  @override
  Future<List<CommunityLocationSuggestion>> search(
    String query, {
    required String sessionToken,
    String? countryCode,
  }) async {
    final cleaned = query.trim();
    if (cleaned.length < 3) {
      throw const CommunityLocationException(
        'Enter at least 3 characters to search.',
      );
    }
    try {
      final response = await _functions
          .httpsCallable('searchCommunityLocations')
          .call({
            'query': cleaned,
            'sessionToken': sessionToken,
            if (countryCode != null) 'countryCode': countryCode,
          });
      final data = response.data;
      final values = data is Map ? data['suggestions'] : null;
      if (values is! List) throw const FormatException();
      return values.whereType<Map>().map((value) {
        final suggestion = Map<String, dynamic>.from(value);
        return CommunityLocationSuggestion(
          placeId: suggestion['placeId'] as String,
          primaryText: suggestion['primaryText'] as String,
          secondaryText: suggestion['secondaryText'] as String,
          displayText: suggestion['displayText'] as String,
        );
      }).toList();
    } on FirebaseFunctionsException catch (error) {
      throw CommunityLocationException(
        error.message ?? 'Location search failed.',
      );
    } catch (_) {
      throw const CommunityLocationException(
        'Location search returned an invalid response.',
      );
    }
  }

  @override
  Future<CommunityLocationSearchResult> resolvePlace(
    String placeId, {
    required String sessionToken,
  }) async {
    try {
      final response = await _functions
          .httpsCallable('resolveCommunityLocationPlace')
          .call({'placeId': placeId, 'sessionToken': sessionToken});
      final data = response.data;
      final value = data is Map ? data['result'] : null;
      if (value is! Map) throw const FormatException();
      final result = Map<String, dynamic>.from(value);
      return CommunityLocationSearchResult(
        latitude: (result['latitude'] as num).toDouble(),
        longitude: (result['longitude'] as num).toDouble(),
        formattedAddress: result['formattedAddress'] as String,
        placeId: result['placeId'] as String,
      );
    } on FirebaseFunctionsException catch (error) {
      throw CommunityLocationException(
        error.message ?? 'The selected place could not be loaded.',
      );
    } catch (_) {
      throw const CommunityLocationException(
        'Place details returned an invalid response.',
      );
    }
  }

  @override
  Future<CommunityLocationSearchResult?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await _functions
          .httpsCallable('reverseGeocodeCommunityLocation')
          .call({'latitude': latitude, 'longitude': longitude});
      final data = response.data;
      final value = data is Map ? data['result'] : null;
      if (value == null) return null;
      if (value is! Map) throw const FormatException();
      final result = Map<String, dynamic>.from(value);
      return CommunityLocationSearchResult(
        latitude: (result['latitude'] as num).toDouble(),
        longitude: (result['longitude'] as num).toDouble(),
        formattedAddress: result['formattedAddress'] as String,
        placeId: result['placeId'] as String?,
      );
    } on FirebaseFunctionsException catch (error) {
      throw CommunityLocationException(
        error.message ??
            'The address could not be determined. Enter it manually.',
      );
    } catch (_) {
      throw const CommunityLocationException(
        'Reverse geocoding returned an invalid response. Enter the address manually.',
      );
    }
  }

  @override
  Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw const CommunityLocationException(
        'Location services are disabled. Please enable location services.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const CommunityLocationException('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const CommunityLocationException(
        'Location permission is permanently denied. Enable it from device settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
