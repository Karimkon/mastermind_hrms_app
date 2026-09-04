/// One person's office clock in/out for a single day.
///
/// Mirrors the `office_attendance` table on the server. Deliberately separate
/// from [AttendanceModel]: that one drives payroll days, this one is a presence
/// register only and never affects anyone's pay.
class OfficeAttendanceModel {
  final int id;
  final int userId;
  final String? userName;
  final String date;
  final String? clockIn;
  final String? clockOut;
  final String? clockInTime;
  final String? clockOutTime;
  final double? hours;
  final int? clockInDistanceM;
  final int? clockOutDistanceM;
  final bool clockInOffsite;
  final bool clockOutOffsite;
  final bool isOpen;
  final String statusLabel;

  const OfficeAttendanceModel({
    required this.id,
    required this.userId,
    this.userName,
    required this.date,
    this.clockIn,
    this.clockOut,
    this.clockInTime,
    this.clockOutTime,
    this.hours,
    this.clockInDistanceM,
    this.clockOutDistanceM,
    this.clockInOffsite = false,
    this.clockOutOffsite = false,
    this.isOpen = false,
    this.statusLabel = 'Not clocked in',
  });

  bool get hasClockedIn => clockIn != null;
  bool get isComplete => clockIn != null && clockOut != null;

  static double? _toDouble(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  static int? _toInt(dynamic v) =>
      v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

  factory OfficeAttendanceModel.fromJson(Map<String, dynamic> j) => OfficeAttendanceModel(
        id: _toInt(j['id']) ?? 0,
        userId: _toInt(j['user_id']) ?? 0,
        userName: j['user_name'] as String?,
        date: j['date']?.toString() ?? '',
        clockIn: j['clock_in'] as String?,
        clockOut: j['clock_out'] as String?,
        clockInTime: j['clock_in_time'] as String?,
        clockOutTime: j['clock_out_time'] as String?,
        hours: _toDouble(j['hours']),
        clockInDistanceM: _toInt(j['clock_in_distance_m']),
        clockOutDistanceM: _toInt(j['clock_out_distance_m']),
        clockInOffsite: j['clock_in_offsite'] == true,
        clockOutOffsite: j['clock_out_offsite'] == true,
        isOpen: j['is_open'] == true,
        statusLabel: j['status_label']?.toString() ?? 'Not clocked in',
      );
}

/// A row on the daily register: someone expected at the office, and their
/// record for the day if they have one. A null [log] is the whole point —
/// it shows who did not clock in.
class OfficeRosterEntry {
  final int userId;
  final String userName;
  final List<String> roles;
  final OfficeAttendanceModel? log;

  const OfficeRosterEntry({
    required this.userId,
    required this.userName,
    this.roles = const [],
    this.log,
  });

  bool get missing => log == null || !log!.hasClockedIn;

  factory OfficeRosterEntry.fromJson(Map<String, dynamic> j) => OfficeRosterEntry(
        userId: OfficeAttendanceModel._toInt(j['user_id']) ?? 0,
        userName: j['user_name']?.toString() ?? '—',
        roles: (j['roles'] as List?)?.map((r) => r.toString()).toList() ?? const [],
        log: j['log'] == null
            ? null
            : OfficeAttendanceModel.fromJson(Map<String, dynamic>.from(j['log'] as Map)),
      );
}

/// Head-office coordinates, used to show how far away a clock-in was.
class OfficeLocation {
  final bool hasCoordinates;
  final double? lat;
  final double? lng;
  final double? radius;

  const OfficeLocation({
    this.hasCoordinates = false,
    this.lat,
    this.lng,
    this.radius,
  });

  factory OfficeLocation.fromJson(Map<String, dynamic> j) => OfficeLocation(
        hasCoordinates: j['has_coordinates'] == true,
        lat: OfficeAttendanceModel._toDouble(j['lat']),
        lng: OfficeAttendanceModel._toDouble(j['lng']),
        radius: OfficeAttendanceModel._toDouble(j['radius']),
      );
}

/// Counters across the register for one day.
class OfficeAttendanceSummary {
  final int expected;
  final int clockedIn;
  final int stillIn;
  final int missing;
  final int offsite;

  const OfficeAttendanceSummary({
    this.expected = 0,
    this.clockedIn = 0,
    this.stillIn = 0,
    this.missing = 0,
    this.offsite = 0,
  });

  factory OfficeAttendanceSummary.fromJson(Map<String, dynamic> j) => OfficeAttendanceSummary(
        expected: OfficeAttendanceModel._toInt(j['expected']) ?? 0,
        clockedIn: OfficeAttendanceModel._toInt(j['clocked_in']) ?? 0,
        stillIn: OfficeAttendanceModel._toInt(j['still_in']) ?? 0,
        missing: OfficeAttendanceModel._toInt(j['missing']) ?? 0,
        offsite: OfficeAttendanceModel._toInt(j['offsite']) ?? 0,
      );
}
