import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/employee_model.dart';

Map<String, dynamic> _parseStr(String s) {
  if (s.isEmpty) return {};
  final m = <String, dynamic>{};
  for (final p in s.split('&')) {
    final i = p.indexOf('=');
    if (i > 0) m[p.substring(0, i)] = p.substring(i + 1);
  }
  return m;
}

final employeeListProvider = FutureProvider.family<List<EmployeeModel>, String>(
  (ref, paramsStr) async {
    try {
      final res = await ApiService.get(ApiConstants.employees, params: _parseStr(paramsStr));
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => EmployeeModel.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  },
);

final employeeDetailProvider = FutureProvider.family<EmployeeModel?, int>((ref, id) async {
  try {
    final res = await ApiService.get('${ApiConstants.employees}/$id');
    final body = res.data as Map<String, dynamic>;
    return EmployeeModel.fromJson(body['data'] as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.departments);
    final body = res.data as Map<String, dynamic>;
    final List list = body['data'] as List? ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

final clientsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.clients);
    final body = res.data as Map<String, dynamic>;
    final List list = (body['data'] is List) ? body['data'] as List : (body['data'] as Map)['data'] ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

final designationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.designations);
    final body = res.data as Map<String, dynamic>;
    final List list = body['data'] as List? ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

class EmployeeActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> createEmployee(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.employees, data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  /// Save an employee edit, and say what the server made of it.
  ///
  /// This returned a bare true/false and the screen then said "Employee
  /// updated" on its own authority. For an account manager that sentence is
  /// wrong: their edit is a proposal that HR has to approve, and nothing on
  /// the record has moved. The server already writes the right sentence —
  /// "Sent to HR for approval", "Nothing was changed", or that it saved — so
  /// it is carried back rather than invented here. On a refusal the message
  /// is the server's too, which for a 422 is the field that was rejected.
  Future<({bool ok, String message})> updateEmployee(
    int id,
    Map<String, dynamic> data,
  ) async {
    state = const AsyncLoading();
    try {
      final resp = await ApiService.put('${ApiConstants.employees}/$id', data: data);
      state = const AsyncData(null);

      final body = resp.data;
      final said = body is Map ? body['message'] : null;

      return (
        ok: true,
        message: said is String && said.trim().isNotEmpty
            ? said.trim()
            : 'Saved.',
      );
    } catch (e) {
      state = AsyncError(e, StackTrace.current);

      return (
        ok: false,
        message: e is ApiException ? e.message : 'That could not be saved.',
      );
    }
  }
}

final employeeActionsProvider =
    NotifierProvider<EmployeeActionsNotifier, AsyncValue<void>>(EmployeeActionsNotifier.new);
