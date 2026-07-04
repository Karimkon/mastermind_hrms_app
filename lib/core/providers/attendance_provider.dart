import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/attendance_model.dart';

// Helper: parse a query-string into a Map (e.g. "month=5&year=2026" → {month:5,year:2026})
Map<String, dynamic> _parseParams(String paramsStr) {
  if (paramsStr.isEmpty) return {};
  final result = <String, dynamic>{};
  for (final pair in paramsStr.split('&')) {
    final idx = pair.indexOf('=');
    if (idx > 0) result[pair.substring(0, idx)] = pair.substring(idx + 1);
  }
  return result;
}

// ─── Today's attendance state (includes assigned work site) ───────────────────

class AttendanceTodayState {
  final AttendanceModel? log;
  final Map<String, dynamic>? workSite;

  const AttendanceTodayState({this.log, this.workSite});
}

class AttendanceTodayNotifier extends AsyncNotifier<AttendanceTodayState> {
  @override
  Future<AttendanceTodayState> build() => _fetch();

  Future<AttendanceTodayState> _fetch() async {
    try {
      final res = await ApiService.get(ApiConstants.attendanceToday);
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      final workSite = body['work_site'] as Map<String, dynamic>?;
      final log = data != null ? AttendanceModel.fromJson(data as Map<String, dynamic>) : null;
      return AttendanceTodayState(log: log, workSite: workSite);
    } catch (_) {
      return const AttendanceTodayState();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> clockIn() async {
    final position = await _getPosition();
    try {
      await ApiService.post(ApiConstants.clockIn, data: position != null
          ? {'latitude': position.latitude, 'longitude': position.longitude}
          : {});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['geo_error'] == true) {
        throw Exception(data['message'] ?? 'You are outside the work site geo-fence.');
      }
      final msg = (data is Map ? data['message'] : null) ?? e.message ?? 'Clock in failed.';
      throw Exception(msg);
    }
    await refresh();
  }

  Future<void> clockOut() async {
    final position = await _getPosition();
    try {
      await ApiService.post(ApiConstants.clockOut, data: position != null
          ? {'latitude': position.latitude, 'longitude': position.longitude}
          : {});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['geo_error'] == true) {
        throw Exception(data['message'] ?? 'You are outside the work site geo-fence.');
      }
      final msg = (data is Map ? data['message'] : null) ?? e.message ?? 'Clock out failed.';
      throw Exception(msg);
    }
    await refresh();
  }

  Future<Position?> _getPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }
}

final attendanceTodayProvider =
    AsyncNotifierProvider<AttendanceTodayNotifier, AttendanceTodayState>(
        AttendanceTodayNotifier.new);

// ─── Attendance list — uses String param for stable equality ──────────────────
// e.g. "month=5&year=2026&status=present"
final attendanceListProvider = FutureProvider.family<List<AttendanceModel>, String>(
  (ref, paramsStr) async {
    try {
      final params = _parseParams(paramsStr);
      final res = await ApiService.get(ApiConstants.attendance, params: params);
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => AttendanceModel.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  },
);

// ─── Attendance report stats ──────────────────────────────────────────────────
final attendanceReportProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, paramsStr) async {
    try {
      final params = _parseParams(paramsStr);
      final res = await ApiService.get(ApiConstants.attendanceReport, params: params);
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  },
);
