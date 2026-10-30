import 'dart:math' as math;

import '../models/am_visit_model.dart';

/// How far somebody is from a work site, and what the server will do about it.
///
/// The arithmetic is deliberately the same haversine the server uses, and the
/// verdict follows the same rule, so the phone and the server cannot disagree.
/// They already did once: the web page measured against the legacy
/// `work_site_lat/lng` pair while the server measured against the mapped
/// sites, which for one client are about a kilometre apart - so the screen
/// showed a distance that had nothing to do with the decision being made.
///
/// Telling somebody they are 4 km away before they tap is worth more than
/// refusing them afterwards: at that point they can still do something.
enum FenceVerdict {
  /// Nobody has pinned this client, so there is nothing to measure against.
  /// The visit is recorded and flagged rather than refused.
  notMapped,

  /// No position yet. Ask for one before judging anybody.
  noFix,

  /// Inside the radius of the nearest premises.
  inside,

  /// Outside, and the server will record it with a flag.
  outsideFlagged,

  /// Outside, and the server will refuse it.
  outsideRefused,
}

class FenceCheck {
  final FenceVerdict verdict;

  /// Metres to the nearest mapped premises, null when nothing was measured.
  final double? metres;

  /// The premises measured against, null when nothing was measured.
  final WorkSiteModel? nearest;

  const FenceCheck(this.verdict, {this.metres, this.nearest});

  bool get blocksClockIn => verdict == FenceVerdict.outsideRefused;

  /// Distance in words. Metres below a kilometre, because "0.1 km" tells
  /// somebody standing in a car park nothing useful.
  String get distanceLabel {
    final m = metres;
    if (m == null) return '';
    return m >= 1000
        ? '${(m / 1000).toStringAsFixed(1)} km'
        : '${m.round()} m';
  }
}

/// Straight-line metres between two fixes.
double metresBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;

  double toRad(double d) => d * math.pi / 180.0;

  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);

  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);

  return 2 * earthRadius * math.asin(math.sqrt(a.toDouble()));
}

/// Where this person stands relative to a client's premises.
///
/// Mirrors ChecksWorkSiteLocation on the server: nearest premises wins, a
/// client with nothing mapped is never refused, and only a client somebody
/// has confirmed as fully mapped can refuse at all.
FenceCheck checkFence(
  AmVisitClientModel client, {
  double? lat,
  double? lng,
}) {
  if (!client.isMapped) {
    return const FenceCheck(FenceVerdict.notMapped);
  }

  if (lat == null || lng == null) {
    return const FenceCheck(FenceVerdict.noFix);
  }

  WorkSiteModel? nearest;
  double? best;

  for (final site in client.sites) {
    final away = metresBetween(lat, lng, site.lat, site.lng);
    if (best == null || away < best) {
      best = away;
      nearest = site;
    }
  }

  if (nearest == null || best == null) {
    return const FenceCheck(FenceVerdict.notMapped);
  }

  if (best <= nearest.radius) {
    return FenceCheck(FenceVerdict.inside, metres: best, nearest: nearest);
  }

  return FenceCheck(
    client.geofenceEnforced
        ? FenceVerdict.outsideRefused
        : FenceVerdict.outsideFlagged,
    metres: best,
    nearest: nearest,
  );
}
