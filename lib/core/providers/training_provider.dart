import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';

final trainingCoursesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.training);
    final body = res.data as Map<String, dynamic>;
    final rawList = body['data'];
    final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

final certificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.certifications);
    final body = res.data as Map<String, dynamic>;
    final List list = body['data'] as List? ?? [];
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

class TrainingActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> enroll(int courseId) async {
    state = const AsyncLoading();
    try {
      await ApiService.post('${ApiConstants.training}/$courseId/enroll');
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> updateProgress(int courseId, int progress) async {
    state = const AsyncLoading();
    try {
      await ApiService.put('${ApiConstants.training}/$courseId/progress', data: {'progress': progress});
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}

final trainingActionsProvider =
    NotifierProvider<TrainingActionsNotifier, AsyncValue<void>>(TrainingActionsNotifier.new);
