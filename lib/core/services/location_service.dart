import 'package:geolocator/geolocator.dart';

/// Result of asking the device where it is.
///
/// Office attendance records a clock-in whether or not GPS is available, so
/// this never throws — a refusal comes back as a [LocationResult] with a
/// [message] and no coordinates, and the caller carries on.
class LocationResult {
  final double? lat;
  final double? lng;
  final double? accuracy;
  final String? message;

  const LocationResult({this.lat, this.lng, this.accuracy, this.message});

  bool get hasFix => lat != null && lng != null;
}

class LocationService {
  /// Ask for a position, requesting permission if needed.
  ///
  /// Handles the three refusals that actually happen on a phone: location
  /// services switched off, permission denied once, and permission denied
  /// permanently (which on iOS needs a trip to Settings).
  static Future<LocationResult> current({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(
          message: 'Location services are switched off on this device.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult(
          message: 'Location permission was denied.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          message: 'Location permission is permanently denied. '
              'Enable it for this app in your device settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return LocationResult(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      // A timeout or a platform hiccup must not stop someone clocking in.
      return LocationResult(message: 'Could not get a location fix ($e).');
    }
  }
}
