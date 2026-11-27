import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../models/supervisor_model.dart';
import '../services/api_service.dart';

/// The field supervisor's data.
///
/// Everything is scoped by the server to the supervisor's current postings,
/// so nothing here filters. A 409 means "you have no posting", which is a
/// different fact from an empty list and is surfaced as such.

/// Thrown when the signed-in supervisor has no current posting.
///
/// Its own type because the screens treat it differently from a failure:
/// there is nothing to retry and nothing is broken. Somebody has to assign
/// them to a site.
class NoPostingException implements Exception {
  final String message;
  const NoPostingException(this.message);

  @override
  String toString() => message;
}

Never _rethrowAsNoPosting(Object error) {
  if (error is ApiException && error.statusCode == 409) {
    throw NoPostingException(error.message);
  }
  throw error;
}

final supervisorDashboardProvider =
    FutureProvider.autoDispose<SupervisorDashboardModel>((ref) async {
  try {
    final resp = await ApiService.get(ApiConstants.supervisorDashboard);
    return SupervisorDashboardModel.fromJson(Map<String, dynamic>.from(resp.data as Map));
  } catch (e) {
    _rethrowAsNoPosting(e);
  }
});

/// The workforce list. The family key is the search term, so typing a name
/// does not invalidate the unsearched list behind it.
///
/// EVERY page, not the first one.
///
/// This asked for page one and ignored `meta` entirely, so a supervisor at
/// Lakeside - 439 people - got thirty, scrolled to the Bs and stopped. Nothing
/// on screen said the list had been cut: it looked exactly like a site with
/// thirty staff on it, which is the worst way for a roll call to be wrong.
final supervisorWorkforceProvider = FutureProvider.autoDispose
    .family<List<SupervisorEmployeeModel>, String>((ref, query) async {
  try {
    final people = <SupervisorEmployeeModel>[];
    var page = 1;

    // A hard stop as well as the `last_page` test. If the server ever answers
    // with a meta that does not advance, this must end a long way short of
    // emptying the battery - a truncated list is a bug, an endless loop is a
    // dead phone.
    const maxPages = 40;

    while (page <= maxPages) {
      final resp = await ApiService.get(
        ApiConstants.supervisorWorkforce,
        params: {
          'page': '$page',
          'per_page': '200',
          if (query.isNotEmpty) 'q': query,
        },
      );

      final body = resp.data as Map;

      people.addAll(((body['data'] as List)
          .map((j) => SupervisorEmployeeModel.fromJson(Map<String, dynamic>.from(j as Map)))));

      final meta = body['meta'] as Map?;
      final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;

      if (page >= lastPage) break;
      page++;
    }

    return people;
  } catch (e) {
    _rethrowAsNoPosting(e);
  }
});

final supervisorEmployeeProvider = FutureProvider.autoDispose
    .family<SupervisorEmployeeDetail, int>((ref, id) async {
  final resp = await ApiService.get('${ApiConstants.supervisorWorkforce}/$id');
  return SupervisorEmployeeDetail.fromJson(Map<String, dynamic>.from(resp.data as Map));
});

final supervisorRequestsProvider =
    FutureProvider.autoDispose<List<PendingChangeModel>>((ref) async {
  final resp = await ApiService.get(ApiConstants.supervisorMyRequests);

  return ((resp.data as Map)['data'] as List)
      .map((j) => PendingChangeModel.fromJson(Map<String, dynamic>.from(j as Map)))
      .toList();
});

/// Send a proposed change.
///
/// Returns the server's own sentence rather than one written here: it is the
/// server that knows whether this went to an account manager, and saying so
/// in two places means saying it differently in two places eventually.
Future<String> proposeEmployeeChange(
  WidgetRef ref,
  int employeeId,
  Map<String, String> fields,
) async {
  final resp = await ApiService.put(
    '${ApiConstants.supervisorWorkforce}/$employeeId',
    data: fields,
  );

  // The detail screen's contract has changed — can_propose is now false —
  // and so has the list of what this person has asked for.
  ref.invalidate(supervisorEmployeeProvider(employeeId));
  ref.invalidate(supervisorRequestsProvider);

  final data = resp.data;
  return data is Map && data['message'] != null
      ? data['message'].toString()
      : 'Sent to the account manager.';
}

/// Recording that somebody has stopped working, from the phone.
///
/// The one supervisor action that is not a proposal. The rules - who may do
/// it, which four states are offered, what it does to attendance and pay -
/// all live on the server in SupervisorController::applyStatusChange(), which
/// the web calls too, so the phone cannot be more permissive than the browser.
class SupervisorActions {
  /// The four choices, read from the server so the app never invents one.
  static Future<List<Map<String, dynamic>>> statusChoices() async {
    try {
      final resp = await ApiService.get('/supervisor/status-choices');

      return ((resp.data as Map)['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      // A last resort so the sheet is never empty. Kept in step with
      // SupervisorController::STATUS_CHOICES.
      return const [
        {'value': 'terminated', 'label': 'Left / terminated', 'hint': 'They have gone and are not coming back.'},
        {'value': 'suspended', 'label': 'Suspended', 'hint': 'Stood down for now, pending a decision.'},
        {'value': 'contract_expired', 'label': 'Contract expired', 'hint': 'Their contract has run out.'},
        {'value': 'on_hold', 'label': 'On hold', 'hint': 'Not working for a period, then expected back.'},
      ];
    }
  }

  /// Returns the server's own sentence, or null when it refused.
  static Future<String?> recordStatus(
    int employeeId, {
    required String state,
    required String reason,
  }) async {
    try {
      final resp = await ApiService.post(
        '${ApiConstants.supervisorWorkforce}/$employeeId/status',
        data: {'state': state, 'reason': reason},
      );

      final data = resp.data;
      return data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Recorded.';
    } catch (_) {
      return null;
    }
  }
}

/// The site's payroll runs, newest first.
///
/// Walks every page for the same reason the workforce provider does: a site
/// that has been running for two years has more runs than one page holds, and
/// a list silently cut at thirty looks exactly like a site with thirty runs.
final supervisorPayrollProvider =
    FutureProvider.autoDispose<List<SitePayrollRun>>((ref) async {
  try {
    final runs = <SitePayrollRun>[];
    var page = 1;
    const maxPages = 20;

    while (page <= maxPages) {
      final resp = await ApiService.get(
        ApiConstants.supervisorPayroll,
        params: {'page': '$page'},
      );

      final body = resp.data as Map;

      runs.addAll(((body['data'] as List)
          .map((j) => SitePayrollRun.fromJson(Map<String, dynamic>.from(j as Map)))));

      final lastPage = ((body['meta'] as Map?)?['last_page'] as num?)?.toInt() ?? 1;
      if (page >= lastPage) break;
      page++;
    }

    return runs;
  } catch (e) {
    _rethrowAsNoPosting(e);
  }
});

final supervisorPayslipsProvider =
    FutureProvider.autoDispose.family<SitePayrollDetail, int>((ref, runId) async {
  final resp = await ApiService.get(ApiConstants.supervisorPayslips(runId));

  return SitePayrollDetail.fromJson(Map<String, dynamic>.from(resp.data as Map));
});
