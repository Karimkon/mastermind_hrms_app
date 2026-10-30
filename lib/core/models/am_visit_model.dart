class AmVisitSessionModel {
  final int id;
  final int clientId;
  final String clientName;
  final String? siteAddress;
  final DateTime clockedInAt;
  final DateTime? clockedOutAt;
  final double? latIn;
  final double? lngIn;
  final double? latOut;
  final double? lngOut;
  final String? notes;
  final double? durationHours;
  final bool isActive;

  const AmVisitSessionModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.siteAddress,
    required this.clockedInAt,
    this.clockedOutAt,
    this.latIn,
    this.lngIn,
    this.latOut,
    this.lngOut,
    this.notes,
    this.durationHours,
    required this.isActive,
  });

  factory AmVisitSessionModel.fromJson(Map<String, dynamic> j) =>
      AmVisitSessionModel(
        id:             j['id'],
        clientId:       j['client_id'],
        clientName:     j['client_name'] ?? '',
        siteAddress:    j['site_address'],
        clockedInAt:    DateTime.parse(j['clocked_in_at']),
        clockedOutAt:   j['clocked_out_at'] != null ? DateTime.parse(j['clocked_out_at']) : null,
        latIn:          (j['lat_in'] as num?)?.toDouble(),
        lngIn:          (j['lng_in'] as num?)?.toDouble(),
        latOut:         (j['lat_out'] as num?)?.toDouble(),
        lngOut:         (j['lng_out'] as num?)?.toDouble(),
        notes:          j['notes'],
        durationHours:  (j['duration_hours'] as num?)?.toDouble(),
        isActive:       j['is_active'] ?? false,
      );

  String get formattedDuration {
    if (durationHours == null) return '--';
    final h = durationHours!.floor();
    final m = ((durationHours! - h) * 60).round();
    return '${h}h ${m}m';
  }
}

/// One place a clock-in may legitimately happen.
///
/// A client can have several. Roofings has two, about ten kilometres apart,
/// and the nearest one is what the server measures against - so the app has
/// to know about all of them or it will show a distance the server disagrees
/// with.
class WorkSiteModel {
  final String name;
  final double lat;
  final double lng;
  final int radius;

  const WorkSiteModel({
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
  });

  factory WorkSiteModel.fromJson(Map<String, dynamic> j) => WorkSiteModel(
        name:   j['name'] ?? 'Work site',
        lat:    (j['lat'] as num).toDouble(),
        lng:    (j['lng'] as num).toDouble(),
        radius: (j['radius'] as num?)?.toInt() ?? 100,
      );
}

class AmVisitClientModel {
  final int id;
  final String companyName;
  final String? workSiteAddress;
  final double? workSiteLat;
  final double? workSiteLng;
  final int? geoFenceRadius;

  /// The places the server will actually accept a clock-in at.
  ///
  /// Prefer this over workSiteLat/workSiteLng, which are the legacy single
  /// pair kept only so older builds keep working. For some clients the two
  /// disagree by about a kilometre.
  final List<WorkSiteModel> sites;

  /// Whether being outside the fence stops a clock-in, or merely flags it.
  /// Off until somebody confirms every premises of that client is mapped.
  final bool geofenceEnforced;

  const AmVisitClientModel({
    required this.id,
    required this.companyName,
    this.workSiteAddress,
    this.workSiteLat,
    this.workSiteLng,
    this.geoFenceRadius,
    this.sites = const [],
    this.geofenceEnforced = false,
  });

  bool get isMapped => sites.isNotEmpty;

  factory AmVisitClientModel.fromJson(Map<String, dynamic> j) =>
      AmVisitClientModel(
        id:               j['id'],
        companyName:      j['company_name'] ?? '',
        workSiteAddress:  j['work_site_address'],
        workSiteLat:      (j['work_site_lat'] as num?)?.toDouble(),
        workSiteLng:      (j['work_site_lng'] as num?)?.toDouble(),
        geoFenceRadius:   j['geo_fence_radius'] as int?,
        // Absent on an older server, which simply means no fence data and
        // therefore no distance shown - not a crash.
        sites: ((j['sites'] as List?) ?? const [])
            .map((s) => WorkSiteModel.fromJson(s as Map<String, dynamic>))
            .toList(),
        geofenceEnforced: j['geofence_enforced'] == true,
      );
}
