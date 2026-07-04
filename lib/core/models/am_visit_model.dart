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

class AmVisitClientModel {
  final int id;
  final String companyName;
  final String? workSiteAddress;
  final double? workSiteLat;
  final double? workSiteLng;
  final int? geoFenceRadius;

  const AmVisitClientModel({
    required this.id,
    required this.companyName,
    this.workSiteAddress,
    this.workSiteLat,
    this.workSiteLng,
    this.geoFenceRadius,
  });

  factory AmVisitClientModel.fromJson(Map<String, dynamic> j) =>
      AmVisitClientModel(
        id:               j['id'],
        companyName:      j['company_name'] ?? '',
        workSiteAddress:  j['work_site_address'],
        workSiteLat:      (j['work_site_lat'] as num?)?.toDouble(),
        workSiteLng:      (j['work_site_lng'] as num?)?.toDouble(),
        geoFenceRadius:   j['geo_fence_radius'] as int?,
      );
}
