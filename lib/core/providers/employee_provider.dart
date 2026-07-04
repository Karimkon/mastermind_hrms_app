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

  Future<bool> updateEmployee(int id, Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.put('${ApiConstants.employees}/$id', data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}

final employeeActionsProvider =
    NotifierProvider<EmployeeActionsNotifier, AsyncValue<void>>(EmployeeActionsNotifier.new);
