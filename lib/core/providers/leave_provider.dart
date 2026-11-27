import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/leave_model.dart';

// Leave requests list — uses String param for stable FutureProvider.family equality.
// Dart Maps use reference equality, causing infinite reloads if used as family param.
final leaveListProvider = FutureProvider.family<List<LeaveRequestModel>, String>(
  (ref, paramsStr) async {
    try {
      final params = <String, dynamic>{};
      for (final pair in paramsStr.split('&')) {
        if (pair.isEmpty) continue;
        final idx = pair.indexOf('=');
        if (idx > 0) params[pair.substring(0, idx)] = pair.substring(idx + 1);
      }
      final res = await ApiService.get(ApiConstants.leaves, params: params);
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => LeaveRequestModel.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  },
);

// Leave types
final leaveTypesProvider = FutureProvider<List<LeaveTypeModel>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.leaveTypes);
    final body = res.data as Map<String, dynamic>;
    final List list = body['data'] as List? ?? [];
    return list.map((j) => LeaveTypeModel.fromJson(j)).toList();
  } catch (_) {
    return [];
  }
});

// Leave balance
final leaveBalanceProvider = FutureProvider<List<LeaveBalanceModel>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.leaveBalance);
    final body = res.data as Map<String, dynamic>;
    final List list = body['data'] as List? ?? [];
    return list.map((j) => LeaveBalanceModel.fromJson(j)).toList();
  } catch (_) {
    return [];
  }
});

// Leave actions notifier
class LeaveActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// The staff this person may apply on behalf of.
  ///
  /// Empty for somebody with nobody under them, which is how the dialog
  /// decides whether to show the chooser at all - an ordinary member of staff
  /// should not be offered a list containing only themselves. A field
  /// supervisor gets the workforce at the site they are posted to.
  static Future<List<Map<String, dynamic>>> filingOptions() async {
    try {
      final resp = await ApiService.get(ApiConstants.leaveFilingOptions);

      return ((resp.data as Map)['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      // The chooser is an extra, never a blocker: if this cannot be read the
      // dialog still applies for the person signed in.
      return const [];
    }
  }

  /// Who may be named as covering this leave.
  ///
  /// Separate from filingOptions(): an office-based account manager may file
  /// leave for hundreds of people placed at client sites and not one of them
  /// can cover her desk, so the server answers this one differently.
  static Future<List<Map<String, dynamic>>> coverOptions() async {
    try {
      final resp = await ApiService.get(ApiConstants.leaveCoverOptions);

      return ((resp.data as Map)['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      // Never a blocker: the server treats cover as optional, so a failure
      // here leaves the field empty rather than stopping the application.
      return const [];
    }
  }

  Future<bool> applyLeave(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.leaves, data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> approveLeave(int id) async {
    state = const AsyncLoading();
    try {
      await ApiService.post('${ApiConstants.leaves}/$id/approve');
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> rejectLeave(int id, String reason) async {
    state = const AsyncLoading();
    try {
      await ApiService.post('${ApiConstants.leaves}/$id/reject', data: {'rejection_reason': reason});
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> cancelLeave(int id) async {
    state = const AsyncLoading();
    try {
      await ApiService.post('${ApiConstants.leaves}/$id/cancel');
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}

final leaveActionsProvider =
    NotifierProvider<LeaveActionsNotifier, AsyncValue<void>>(LeaveActionsNotifier.new);
