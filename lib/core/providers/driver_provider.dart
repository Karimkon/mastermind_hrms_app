import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/api_constants.dart';
import '../services/api_service.dart';

/// One place the driver stopped.
class DriverStop {
  final int id;
  final String place;
  final String? purpose;
  final String? arrivedAt;
  final String? departedAt;
  final int? minutes;
  final bool open;
  final bool positionTrusted;
  final bool matchedSite;
  final int? fromPreviousM;

  const DriverStop({
    required this.id,
    required this.place,
    this.purpose,
    this.arrivedAt,
    this.departedAt,
    this.minutes,
    required this.open,
    required this.positionTrusted,
    required this.matchedSite,
    this.fromPreviousM,
  });

  factory DriverStop.fromJson(Map<String, dynamic> j) => DriverStop(
        id: j['id'] as int,
        place: (j['place'] ?? 'Unnamed stop').toString(),
        purpose: j['purpose'] as String?,
        arrivedAt: j['arrived_at'] as String?,
        departedAt: j['departed_at'] as String?,
        minutes: (j['minutes'] as num?)?.toInt(),
        open: j['open'] == true,
        positionTrusted: j['position_trusted'] == true,
        matchedSite: j['matched_site'] == true,
        fromPreviousM: (j['from_previous_m'] as num?)?.toInt(),
      );
}

/// The driver's day: the stops, and the sentence they add up to.
class DriverDay {
  final String summary;
  final List<DriverStop> stops;
  final int? openStopId;

  const DriverDay({required this.summary, required this.stops, this.openStopId});

  factory DriverDay.fromJson(Map<String, dynamic> j) => DriverDay(
        summary: (j['summary'] ?? '').toString(),
        openStopId: (j['open_stop_id'] as num?)?.toInt(),
        stops: ((j['data'] as List?) ?? const [])
            .map((s) => DriverStop.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

final driverTodayProvider = FutureProvider.autoDispose<DriverDay>((ref) async {
  final resp = await ApiService.get(ApiConstants.driverToday);

  return DriverDay.fromJson(Map<String, dynamic>.from(resp.data as Map));
});

class DriverActions {
  /// Record arriving somewhere.
  ///
  /// The position is read HERE, once, at the moment the driver says they have
  /// arrived — never in the background. That is the whole design: a stop with
  /// a reason beats a trail of coordinates that cannot say why the vehicle
  /// went anywhere, and it keeps the app clear of Android's background
  /// location permission, which Play gates behind its own review.
  ///
  /// Returns what to show the driver: the place that was logged, or the
  /// server's own refusal ("Clock in first…"), which is always more use than
  /// anything this layer could invent.
  static Future<({bool ok, String message})> arrive({
    String? placeName,
    String? purpose,
  }) async {
    Position? fix;

    try {
      fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      // A stop with no position is still worth recording: the driver knows
      // where they are even when the phone does not.
      fix = null;
    }

    try {
      final resp = await ApiService.post(ApiConstants.driverStops, data: {
        if (fix != null) 'lat': fix.latitude,
        if (fix != null) 'lng': fix.longitude,
        if (fix != null) 'accuracy': fix.accuracy.round(),
        if (placeName != null && placeName.trim().isNotEmpty)
          'place_name': placeName.trim(),
        if (purpose != null && purpose.trim().isNotEmpty) 'purpose': purpose.trim(),
      });

      final data = resp.data;
      final place = data is Map && data['data'] is Map
          ? (data['data'] as Map)['place']
          : null;

      return (ok: true, message: place != null ? 'Logged at $place' : 'Stop recorded.');
    } on ApiException catch (e) {
      // The server's own words — "Clock in first. A journey is part of a
      // working day…" — which say far more than a generic failure would.
      return (ok: false, message: e.message);
    } catch (_) {
      return (ok: false, message: 'Could not record that stop. Try again.');
    }
  }

  static Future<void> depart(int stopId) async {
    await ApiService.post(ApiConstants.driverDepart(stopId));
  }
}
