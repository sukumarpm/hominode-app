import 'package:geolocator/geolocator.dart';

class LocationAcquisitionException implements Exception {
  const LocationAcquisitionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocationService {
  static const double maximumCheckInAccuracyMeters = 100;

  Future<Position> getFreshCheckInLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationAcquisitionException(
        'Location services are disabled. Enable GPS and try again.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationAcquisitionException(
        'Location permission is required to check in.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationAcquisitionException(
        'Location permission is permanently denied. Enable it in app settings.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
    if (!position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > maximumCheckInAccuracyMeters) {
      throw const LocationAcquisitionException(
        'GPS accuracy is too low. Move to an open area and try again.',
      );
    }
    return position;
  }

  Future<Position?> tryGetCheckoutLocation() async {
    try {
      return await getFreshCheckInLocation();
    } catch (_) {
      return null;
    }
  }
}
