import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../models/office_attendance_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

/// Today's own record plus the configured office location.
class OfficeTodayState {
  final OfficeAttendanceModel? log;
  final OfficeLocation office;

  const OfficeTodayState({this.log, this.office = const OfficeLocation()});
}

class OfficeTodayNotifier extends AsyncNotifier<OfficeTodayState> {
  @override
  Future<OfficeTodayState> build() => _fetch();

  Future<OfficeTodayState> _fetch() async {
    final resp = await ApiService.get(ApiConstants.officeAttendanceToday);
    final d = Map<String, dynamic>.from(resp.data as Map);

    return OfficeTodayState(
      log: d['data'] == null
          ? null
          : OfficeAttendanceModel.fromJson(Map<String, dynamic>.from(d['data'] as Map)),
      office: d['office'] == null
          ? const OfficeLocation()
          : OfficeLocation.fromJson(Map<String, dynamic>.from(d['office'] as Map)),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Clock in, sending GPS when the device will give it.
  ///
  /// A refused or unavailable fix is not an error: the server records the
  /// clock-in without coordinates rather than blocking it, which is the agreed
  /// behaviour for the office register.
  Future<String> clockIn() => _punch(ApiConstants.officeAttendanceClockIn);

  Future<String> clockOut() => _punch(ApiConstants.officeAttendanceClockOut);

  Future<String> _punch(String endpoint) async {
    final fix = await LocationService.current();

    final resp = await ApiService.post(endpoint, data: {
      if (fix.hasFix) 'lat': fix.lat,
      if (fix.hasFix) 'lng': fix.lng,
    });

    await refresh();

    final message = resp.data is Map
        ? (resp.data['message'] as String? ?? 'Done.')
        : 'Done.';

    return fix.hasFix ? message : '$message (no location recorded — ${fix.message})';
  }
}

final officeTodayProvider =
    AsyncNotifierProvider<OfficeTodayNotifier, OfficeTodayState>(OfficeTodayNotifier.new);

/// The daily register: who was expected, who came, who did not.
class OfficeRegisterState {
  final String date;
  final List<OfficeRosterEntry> roster;
  final OfficeAttendanceSummary summary;
  final bool isSupervisor;

  const OfficeRegisterState({
    this.date = '',
    this.roster = const [],
    this.summary = const OfficeAttendanceSummary(),
    this.isSupervisor = false,
  });
}

class OfficeRegisterNotifier extends FamilyAsyncNotifier<OfficeRegisterState, String?> {
  @override
  Future<OfficeRegisterState> build(String? date) => _fetch(date);

  Future<OfficeRegisterState> _fetch(String? date) async {
    final query = (date == null || date.isEmpty) ? '' : '?date=$date';
    final resp = await ApiService.get('${ApiConstants.officeAttendance}$query');
    final d = Map<String, dynamic>.from(resp.data as Map);

    return OfficeRegisterState(
      date: d['date']?.toString() ?? '',
      roster: (d['data'] as List? ?? [])
          .map((j) => OfficeRosterEntry.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList(),
      summary: d['summary'] == null
          ? const OfficeAttendanceSummary()
          : OfficeAttendanceSummary.fromJson(Map<String, dynamic>.from(d['summary'] as Map)),
      isSupervisor: d['is_supervisor'] == true,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}

final officeRegisterProvider =
    AsyncNotifierProvider.family<OfficeRegisterNotifier, OfficeRegisterState, String?>(
  OfficeRegisterNotifier.new,
);
