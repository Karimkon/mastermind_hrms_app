import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

/// Appraisal cards.
///
/// These replace the `bsc` providers, which talked to the cycle-based scheme the
/// per-employee appraisal tables superseded. Both sets of tables still exist on
/// the server and both are empty, which is exactly why nobody had noticed the
/// phone and the browser were reading different systems.
///
/// Whose move it is comes from the server, in `your_move`. Working it out here
/// would put a second, quieter copy of the workflow in Dart, and the two would
/// disagree the first time the rules changed.

const _base = '/appraisals';

/// Every card this person has a part in — theirs, ones they score, ones they
/// confirm.
final appraisalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiService.get(_base);
  return _list(res.data);
});

/// Just the signed-in employee's own cards, for the self-service view.
final myAppraisalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiService.get('$_base/mine');
  return _list(res.data);
});

/// One card in full: KPIs, actions, and the trail of who did what.
final appraisalDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final res = await ApiService.get('$_base/$id');
  final body = res.data as Map<String, dynamic>;
  return Map<String, dynamic>.from(body['data'] ?? {});
});

/// Unwraps `{data: [...]}`. Kept in one place because getting it wrong shows up
/// as an empty screen rather than an error, which is the hardest kind to notice.
List<Map<String, dynamic>> _list(dynamic body) {
  if (body is! Map) return const [];
  final raw = body['data'];
  if (raw is! List) return const [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

class AppraisalActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> _post(String path, Map<String, dynamic> body) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(path, data: body);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  /// Save what has been rated so far.
  ///
  /// Partial saves are deliberate on both sides: a dozen KPIs are not rated in
  /// one sitting on a phone, and losing half of it to a validation error would
  /// be worse than an incomplete card. The server enforces completeness where it
  /// actually matters — when the card is handed on.
  Future<bool> score(int id, Map<int, Map<String, dynamic>> kpis) {
    return _post('$_base/$id/score', {
      'kpi': kpis.map((k, v) => MapEntry(k.toString(), v)),
    });
  }

  Future<bool> returnToManager(int id, int returnToId, String? comment) {
    return _post('$_base/$id/return', {
      'return_to_id': returnToId,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<bool> confirm(int id, String? managerComment) {
    return _post('$_base/$id/confirm', {
      if (managerComment != null && managerComment.isNotEmpty)
        'manager_comment': managerComment,
    });
  }

  Future<bool> sendBack(int id, String comment) {
    return _post('$_base/$id/send-back', {'comment': comment});
  }

  Future<bool> selfAppraise(int id, String comment) {
    return _post('$_base/$id/self', {'employee_comment': comment});
  }
}

final appraisalActionsProvider =
    NotifierProvider<AppraisalActions, AsyncValue<void>>(AppraisalActions.new);
