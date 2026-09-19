import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

/// Shifts, salary grades and salary components.
///
/// Two of the three are inputs to every payslip, so each list carries the
/// server's `can_configure` rather than the app deciding from a role name it
/// happens to know. Authority is the server's answer, always.

class ConfigList {
  final List<Map<String, dynamic>> items;
  final bool canConfigure;

  const ConfigList({required this.items, required this.canConfigure});
}

ConfigList _parse(dynamic body) {
  if (body is! Map) return const ConfigList(items: [], canConfigure: false);

  final raw = body['data'];

  return ConfigList(
    items: raw is List ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : const [],
    canConfigure: body['can_configure'] == true,
  );
}

final shiftsProvider = FutureProvider<ConfigList>((ref) async {
  final res = await ApiService.get('/shifts');
  return _parse(res.data);
});

final salaryGradesProvider = FutureProvider<ConfigList>((ref) async {
  final res = await ApiService.get('/salary-grades');
  return _parse(res.data);
});

final salaryComponentsProvider = FutureProvider<ConfigList>((ref) async {
  final res = await ApiService.get('/salary-components');
  return _parse(res.data);
});

class ConfigurationActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> _post(String path, Map<String, dynamic> body) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(path, data: body);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _message(e);
    }
  }

  /// The server's own sentence where there is one.
  ///
  /// These endpoints refuse for reasons worth reading — a duplicate code, a
  /// ceiling below its floor, NSSF being statutory — and replacing them with
  /// "could not save" would throw away the only useful part.
  String _message(Object error) {
    final text = error.toString();

    final message = RegExp(r'"message":"([^"]+)"').firstMatch(text)?.group(1);
    if (message != null && message.isNotEmpty) return message;

    // Laravel's validation errors arrive under `errors`, first one first.
    final field = RegExp(r'"errors":\{"[^"]+":\["([^"]+)"').firstMatch(text)?.group(1);
    if (field != null && field.isNotEmpty) return field;

    return 'That could not be saved. Please try again.';
  }

  Future<String?> createShift({
    required String name,
    required String startTime,
    required String endTime,
    required int graceMinutes,
  }) {
    return _post('/shifts', {
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      'grace_minutes': graceMinutes,
    });
  }

  Future<String?> createGrade({
    required String grade,
    String? label,
    required num min,
    required num max,
  }) {
    return _post('/salary-grades', {
      'grade': grade,
      if (label != null && label.isNotEmpty) 'label': label,
      'basic_min': min,
      'basic_max': max,
    });
  }

  Future<String?> createComponent({
    required String name,
    required String code,
    required String type,
    required bool isFixed,
    required bool isTaxable,
    num? amount,
    num? percentage,
  }) {
    return _post('/salary-components', {
      'name': name,
      'code': code,
      'type': type,
      'is_fixed': isFixed,
      'is_taxable': isTaxable,
      if (isFixed) 'amount': amount ?? 0,
      if (!isFixed) 'percentage': percentage ?? 0,
    });
  }

  Future<String?> setComponentActive(int id, bool active) {
    return _post('/salary-components/$id/active', {'is_active': active});
  }
}

final configurationActionsProvider =
    NotifierProvider<ConfigurationActions, AsyncValue<void>>(ConfigurationActions.new);

// ── Public holidays ────────────────────────────────────────────────────────

/// A year of the public holiday calendar.
///
/// `missingFixed` is how many of Uganda's fixed-date holidays this year does not
/// have yet, so the seed button can say what it will do before it is pressed.
class HolidayYear {
  final List<Map<String, dynamic>> holidays;
  final bool canManage;
  final int missingFixed;

  const HolidayYear({
    required this.holidays,
    required this.canManage,
    required this.missingFixed,
  });
}

final publicHolidaysProvider =
    FutureProvider.family<HolidayYear, int>((ref, year) async {
  final res = await ApiService.get('/public-holidays', params: {'year': year});
  final body = res.data;
  final parsed = _parse(body);

  return HolidayYear(
    holidays: parsed.items,
    canManage: body is Map && body['can_manage'] == true,
    missingFixed: body is Map ? ((body['missing_fixed'] as num?)?.toInt() ?? 0) : 0,
  );
});

class HolidayCalendarActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> add({
    required String date,
    required String name,
    required String type,
    required bool isPaid,
  }) async {
    state = const AsyncLoading();
    try {
      await ApiService.post('/public-holidays',
          data: {'date': date, 'name': name, 'type': type, 'is_paid': isPaid});
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _serverMessage(e);
    }
  }

  /// Returns the server's summary, or an error string.
  Future<({int added, String note, String? error})> seed(int year) async {
    state = const AsyncLoading();
    try {
      final res = await ApiService.post('/public-holidays/seed', data: {'year': year});
      state = const AsyncData(null);
      final data = (res.data as Map)['data'] as Map;
      return (
        added: (data['added'] as num?)?.toInt() ?? 0,
        note: data['note']?.toString() ?? '',
        error: null,
      );
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return (added: 0, note: '', error: _serverMessage(e));
    }
  }

  Future<String?> remove(int id) async {
    state = const AsyncLoading();
    try {
      await ApiService.delete('/public-holidays/$id');
      state = const AsyncData(null);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _serverMessage(e);
    }
  }

  /// The refusal reasons here are the whole value — "carries 3 pay decisions and
  /// 12 attendance records" is what stops somebody trying again.
  String _serverMessage(Object error) {
    final text = error.toString();
    final message = RegExp(r'"message":"([^"]+)"').firstMatch(text)?.group(1);
    if (message != null && message.isNotEmpty) return message;
    return 'That could not be saved. Please try again.';
  }
}

final holidayCalendarActionsProvider =
    NotifierProvider<HolidayCalendarActions, AsyncValue<void>>(HolidayCalendarActions.new);
