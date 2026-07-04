import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/payslip_model.dart';

// My payslips (employee)
final myPayslipsProvider = FutureProvider<List<PayslipModel>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.myPayslips);
    final body = res.data as Map<String, dynamic>;
    final rawList = body['data'];
    final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
    return list.map((j) => PayslipModel.fromJson(j)).toList();
  } catch (_) {
    return [];
  }
});

// Payroll runs (HR/payroll officer)
final payrollRunsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.payroll);
    final body = res.data as Map<String, dynamic>;
    final rawList = body['data'];
    final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

// Single payroll run details
final payrollDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  try {
    final res = await ApiService.get('${ApiConstants.payroll}/$id');
    return res.data as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
});

// Payslips for a specific run
final runPayslipsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, runId) async {
  try {
    final res = await ApiService.get('${ApiConstants.payroll}/$runId/payslips');
    final body = res.data as Map<String, dynamic>;
    final List list = body['data'] as List? ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

class PayrollActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> createRun(int month, int year, {int? clientId}) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.payroll, data: {
        'month': month,
        'year': year,
        if (clientId != null) 'client_id': clientId,
      });
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> processPayroll(int id) async {
    state = const AsyncLoading();
    try {
      await ApiService.post('${ApiConstants.payroll}/$id/process');
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> approvePayroll(int id) async {
    state = const AsyncLoading();
    try {
      await ApiService.post('${ApiConstants.payroll}/$id/approve');
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}

final payrollActionsProvider =
    NotifierProvider<PayrollActionsNotifier, AsyncValue<void>>(PayrollActionsNotifier.new);
