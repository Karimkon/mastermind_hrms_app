import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../models/change_approval_model.dart';
import '../services/api_service.dart';

String _message(DioException e, String fallback) {
  final body = e.response?.data;
  if (body is Map && body['message'] is String) return body['message'] as String;
  if (body is Map && body['errors'] is Map) {
    final first = (body['errors'] as Map).values.first;
    if (first is List && first.isNotEmpty) return first.first.toString();
  }
  return e.message ?? fallback;
}

/// The queue, filtered by status ('pending', 'approved', 'rejected').
final changeApprovalsProvider =
    FutureProvider.family.autoDispose<ChangeApprovalsData, String>((ref, status) async {
  try {
    final resp = await ApiService.get(ApiConstants.changeApprovals, params: {'status': status});
    final d = resp.data as Map<String, dynamic>;
    final page = d['data'];
    final List rows = page is Map ? (page['data'] as List? ?? []) : (page as List? ?? []);

    return ChangeApprovalsData(
      changes: rows.map((j) => ChangeApprovalModel.fromJson(Map<String, dynamic>.from(j))).toList(),
      pendingCount: (d['pending_count'] as num?)?.toInt() ?? 0,
      status: d['status'] as String? ?? status,
    );
  } on DioException catch (e) {
    if (e.response?.statusCode == 403) {
      throw Exception('Only HR or an administrator can approve changes.');
    }
    throw Exception(_message(e, 'Could not load the approval queue.'));
  }
});

/// One change with its field-by-field diff — the part that matters.
final changeApprovalProvider =
    FutureProvider.family.autoDispose<ChangeApprovalModel, int>((ref, id) async {
  try {
    final resp = await ApiService.get(ApiConstants.changeApproval(id));
    final d = resp.data as Map<String, dynamic>;
    return ChangeApprovalModel.fromJson(Map<String, dynamic>.from(d['data']));
  } on DioException catch (e) {
    throw Exception(_message(e, 'Could not load that change.'));
  }
});

class ChangeApprovalActions {
  const ChangeApprovalActions(this.ref);
  final Ref ref;

  void _refreshAll() {
    ref.invalidate(changeApprovalsProvider);
    ref.invalidate(changeApprovalProvider);
  }

  Future<String> approve(int id, {String? note}) async {
    try {
      final resp = await ApiService.post(
        ApiConstants.changeApprovalApprove(id),
        data: {if (note != null && note.isNotEmpty) 'review_note': note},
      );
      _refreshAll();
      return (resp.data as Map)['message'] as String? ?? 'Change approved and applied.';
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not approve that change.'));
    }
  }

  /// A reason is required — a refusal without one leaves the account manager
  /// guessing and resubmitting the same thing.
  Future<String> reject(int id, String note) async {
    try {
      final resp = await ApiService.post(
        ApiConstants.changeApprovalReject(id),
        data: {'review_note': note},
      );
      _refreshAll();
      return (resp.data as Map)['message'] as String? ?? 'Change rejected.';
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not reject that change.'));
    }
  }
}

final changeApprovalActionsProvider =
    Provider<ChangeApprovalActions>(ChangeApprovalActions.new);
