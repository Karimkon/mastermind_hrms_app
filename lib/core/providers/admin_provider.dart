import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';

Map<String, dynamic> _parseStr(String s) {
  if (s.isEmpty) return {};
  final m = <String, dynamic>{};
  for (final p in s.split('&')) {
    final i = p.indexOf('=');
    if (i > 0) m[p.substring(0, i)] = p.substring(i + 1);
  }
  return m;
}

final adminUsersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, paramsStr) async {
    try {
      final res = await ApiService.get(ApiConstants.adminUsers, params: _parseStr(paramsStr));
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => j as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  },
);

final adminDepartmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.adminDepartments);
    final body = res.data as Map<String, dynamic>;
    final List list = body['data'] as List? ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

final adminClientsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.adminClients);
    final body = res.data as Map<String, dynamic>;
    final rawList = body['data'];
    final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

final auditLogsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, paramsStr) async {
    try {
      final res = await ApiService.get(ApiConstants.adminAudit, params: _parseStr(paramsStr));
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => j as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  },
);

final adminRolesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.adminRoles);
    final body = res.data as Map<String, dynamic>;
    final List list = body['data'] as List? ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

class AdminActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> createUser(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.adminUsers, data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> updateUser(int id, Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.put('${ApiConstants.adminUsers}/$id', data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> createDepartment(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.adminDepartments, data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> createClient(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.adminClients, data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> deleteClient(int id) async {
    state = const AsyncLoading();
    try {
      await ApiService.delete('${ApiConstants.adminClients}/$id');
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}

final adminActionsProvider =
    NotifierProvider<AdminActionsNotifier, AsyncValue<void>>(AdminActionsNotifier.new);
