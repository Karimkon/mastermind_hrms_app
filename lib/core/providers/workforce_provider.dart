import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

/// Holiday pay, onboarding and PIPs.
///
/// Three small modules in one file because on a phone they are the same shape —
/// a short list belonging to a person or a date, with items somebody ticks. Three
/// separate files would be three copies of the same plumbing.

List<Map<String, dynamic>> _list(dynamic body, [String key = 'data']) {
  if (body is! Map) return const [];
  final raw = body[key];
  if (raw is! List) return const [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

// ── Holiday pay ────────────────────────────────────────────────────────────

/// A year of public holidays with their pay decisions.
///
/// Carries `can_decide` alongside the list: whether this person may approve pay
/// is the server's call, and the screen should not infer it from a role name it
/// happens to know.
class HolidayPayYear {
  final List<Map<String, dynamic>> holidays;
  final bool canDecide;

  const HolidayPayYear({required this.holidays, required this.canDecide});
}

final holidayPayProvider =
    FutureProvider.family<HolidayPayYear, int>((ref, year) async {
  final res = await ApiService.get('/holiday-pay', params: {'year': year});
  final body = res.data;

  return HolidayPayYear(
    holidays: _list(body),
    canDecide: body is Map && body['can_decide'] == true,
  );
});

/// Who could have worked one holiday, for one client.
final holidayRosterProvider =
    FutureProvider.family<Map<String, dynamic>, ({int holidayId, int clientId})>(
        (ref, args) async {
  final res = await ApiService.get(
    '/holiday-pay/${args.holidayId}/roster',
    params: {'client_id': args.clientId},
  );
  final body = res.data as Map<String, dynamic>;
  return Map<String, dynamic>.from(body['data'] ?? {});
});

// ── Onboarding ─────────────────────────────────────────────────────────────

class OnboardingList {
  final List<Map<String, dynamic>> tasks;
  final int done;
  final int total;

  const OnboardingList({required this.tasks, required this.done, required this.total});
}

final onboardingProvider = FutureProvider<OnboardingList>((ref) async {
  final res = await ApiService.get('/onboarding');
  final body = res.data;
  final summary = (body is Map ? body['summary'] : null) as Map? ?? const {};

  return OnboardingList(
    tasks: _list(body),
    done: (summary['done'] as num?)?.toInt() ?? 0,
    total: (summary['total'] as num?)?.toInt() ?? 0,
  );
});

// ── PIPs ───────────────────────────────────────────────────────────────────

final pipsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiService.get('/pips');
  return _list(res.data);
});

// ── Actions ────────────────────────────────────────────────────────────────

class WorkforceActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> _post(String path, Map<String, dynamic> body) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(path, data: body);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> decideHoliday(int holidayId, String status, {int? clientId, String? note}) {
    return _post('/holiday-pay/$holidayId/decide', {
      'status': status,
      'client_id': ?clientId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Records the whole roster, not just the ticks.
  ///
  /// "Nobody worked" and "nobody has said yet" are different facts, and a list
  /// of ticked names alone cannot tell them apart.
  Future<bool> recordHolidayWork(
    int holidayId, {
    required int clientId,
    required List<int> everybody,
    required List<int> worked,
  }) {
    return _post('/holiday-pay/$holidayId/work', {
      'client_id': clientId,
      'employee_ids': everybody,
      'worked_ids': worked,
    });
  }

  Future<bool> setOnboardingTask(int taskId, bool completed) {
    return _post('/onboarding/$taskId/complete', {'completed': completed});
  }
}

final workforceActionsProvider =
    NotifierProvider<WorkforceActions, AsyncValue<void>>(WorkforceActions.new);
