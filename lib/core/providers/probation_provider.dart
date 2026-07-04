import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/probation_model.dart';

class ProbationListData {
  final ProbationStatsModel stats;
  final List<ProbationEmployeeModel> employees;
  final int total;
  final int lastPage;

  const ProbationListData({
    required this.stats,
    this.employees = const [],
    this.total = 0,
    this.lastPage = 1,
  });
}

final probationListProvider =
    FutureProvider.family.autoDispose<ProbationListData, String?>((ref, status) async {
  try {
    final query = status != null ? '?status=$status' : '';
    final resp  = await ApiService.get('${ApiConstants.probation}$query');
    final d     = resp.data as Map<String, dynamic>;

    return ProbationListData(
      stats:     ProbationStatsModel.fromJson(d['stats'] as Map<String, dynamic>),
      employees: (d['data'] as List).map((j) => ProbationEmployeeModel.fromJson(j)).toList(),
      total:     d['total'] ?? 0,
      lastPage:  d['last_page'] ?? 1,
    );
  } on DioException catch (e) {
    final body = e.response?.data;
    final msg  = (body is Map ? body['message'] : null)
        ?? e.message
        ?? 'Failed to load probation data. Please try again.';
    throw Exception(msg);
  }
});

final probationDetailProvider =
    FutureProvider.family.autoDispose<ProbationEmployeeModel, int>((ref, employeeId) async {
  try {
    final resp = await ApiService.get('${ApiConstants.probation}/$employeeId');
    return ProbationEmployeeModel.fromJson(resp.data as Map<String, dynamic>);
  } on DioException catch (e) {
    final body = e.response?.data;
    final msg  = (body is Map ? body['message'] : null) ?? 'Failed to load employee.';
    throw Exception(msg);
  }
});

class ProbationActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<String> setEnd(int employeeId, String endDate) async {
    final resp = await ApiService.post(
      '${ApiConstants.probation}/$employeeId/set-end',
      data: {'probation_end_date': endDate},
    );
    ref.invalidate(probationListProvider);
    ref.invalidate(probationDetailProvider);
    return resp.data['message'] as String? ?? 'Saved.';
  }

  Future<String> confirm(int employeeId, String outcome, {String? notes, String? newEndDate}) async {
    final resp = await ApiService.post(
      '${ApiConstants.probation}/$employeeId/confirm',
      data: {
        'outcome': outcome,
        if (notes != null) 'notes': notes,
        if (newEndDate != null) 'new_probation_end_date': newEndDate,
      },
    );
    ref.invalidate(probationListProvider);
    ref.invalidate(probationDetailProvider);
    return resp.data['message'] as String? ?? 'Confirmed.';
  }
}

final probationActionsProvider =
    NotifierProvider<ProbationActionsNotifier, void>(ProbationActionsNotifier.new);
