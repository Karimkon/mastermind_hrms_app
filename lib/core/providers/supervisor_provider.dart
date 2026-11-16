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
final supervisorWorkforceProvider = FutureProvider.autoDispose
    .family<List<SupervisorEmployeeModel>, String>((ref, query) async {
  try {
    final resp = await ApiService.get(
      ApiConstants.supervisorWorkforce,
      params: query.isEmpty ? null : {'q': query},
    );

    return ((resp.data as Map)['data'] as List)
        .map((j) => SupervisorEmployeeModel.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
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
