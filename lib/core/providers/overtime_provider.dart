import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../models/overtime_model.dart';
import '../services/api_service.dart';

class OvertimeState {
  final List<OvertimeModel> items;
  final OvertimePolicy policy;
  final int pendingTotal;
  final int total;
  final String status;

  const OvertimeState({
    this.items = const [],
    this.policy = const OvertimePolicy(),
    this.pendingTotal = 0,
    this.total = 0,
    this.status = 'pending',
  });

  OvertimeState copyWith({
    List<OvertimeModel>? items,
    OvertimePolicy? policy,
    int? pendingTotal,
    int? total,
    String? status,
  }) =>
      OvertimeState(
        items: items ?? this.items,
        policy: policy ?? this.policy,
        pendingTotal: pendingTotal ?? this.pendingTotal,
        total: total ?? this.total,
        status: status ?? this.status,
      );
}

class OvertimeNotifier extends AsyncNotifier<OvertimeState> {
  String _status = 'pending';

  @override
  Future<OvertimeState> build() => _fetch(_status);

  Future<OvertimeState> _fetch(String status) async {
    final resp = await ApiService.get('${ApiConstants.overtime}?status=$status');
    final d = Map<String, dynamic>.from(resp.data as Map);

    return OvertimeState(
      items: (d['data'] as List? ?? [])
          .map((j) => OvertimeModel.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList(),
      policy: d['policy'] == null
          ? const OvertimePolicy()
          : OvertimePolicy.fromJson(Map<String, dynamic>.from(d['policy'] as Map)),
      pendingTotal: (d['meta']?['pending_total'] as num?)?.toInt() ?? 0,
      total: (d['meta']?['total'] as num?)?.toInt() ?? 0,
      status: status,
    );
  }

  Future<void> setStatus(String status) async {
    _status = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(status));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(_status));
  }

  /// Approve a specific number of hours. Passing more than the policy cap is
  /// allowed on purpose — the caps are guidance, the decision is HR's.
  Future<String> approve(int id, double hours, {String? note}) async {
    final resp = await ApiService.post(ApiConstants.overtimeApprove(id), data: {
      'hours': hours,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    await refresh();
    return resp.data is Map ? (resp.data['message'] as String? ?? 'Approved.') : 'Approved.';
  }

  Future<String> reject(int id, {String? note}) async {
    final resp = await ApiService.post(ApiConstants.overtimeReject(id), data: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
    await refresh();
    return resp.data is Map ? (resp.data['message'] as String? ?? 'Rejected.') : 'Rejected.';
  }
}

final overtimeProvider =
    AsyncNotifierProvider<OvertimeNotifier, OvertimeState>(OvertimeNotifier.new);
