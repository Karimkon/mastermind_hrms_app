import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../models/goal_model.dart';
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

final goalsProvider = FutureProvider.autoDispose<GoalsData>((ref) async {
  try {
    final resp = await ApiService.get(ApiConstants.goals);
    final d = resp.data as Map<String, dynamic>;

    return GoalsData(
      goals: (d['data'] as List? ?? [])
          .map((j) => GoalModel.fromJson(Map<String, dynamic>.from(j)))
          .toList(),
      summary: GoalSummary.fromJson(d['summary'] as Map<String, dynamic>?),
    );
  } on DioException catch (e) {
    throw Exception(_message(e, 'Could not load your goals.'));
  }
});

class GoalActions {
  const GoalActions(this.ref);
  final Ref ref;

  Future<void> create({
    required String title,
    String? description,
    String? targetDate,
    double? weight,
  }) async {
    try {
      await ApiService.post(ApiConstants.goals, data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'target_date': ?targetDate,
        'weight': ?weight,
      });
      ref.invalidate(goalsProvider);
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not save that goal.'));
    }
  }

  /// The server moves the status along with the bar — off zero is in progress,
  /// full is achieved — so the app does not have to guess at it.
  Future<void> setProgress(int id, int progress) async {
    try {
      await ApiService.put(ApiConstants.goal(id), data: {'progress': progress});
      ref.invalidate(goalsProvider);
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not update that goal.'));
    }
  }

  Future<void> setStatus(int id, String status) async {
    try {
      await ApiService.put(ApiConstants.goal(id), data: {'status': status});
      ref.invalidate(goalsProvider);
    } on DioException catch (e) {
      throw Exception(_message(e, 'Could not update that goal.'));
    }
  }
}

final goalActionsProvider = Provider<GoalActions>(GoalActions.new);
