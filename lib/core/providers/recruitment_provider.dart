import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/recruitment_model.dart';

// Helper: parse query-string → Map
Map<String, dynamic> _parseParams(String paramsStr) {
  if (paramsStr.isEmpty) return {};
  final result = <String, dynamic>{};
  for (final pair in paramsStr.split('&')) {
    final idx = pair.indexOf('=');
    if (idx > 0) result[pair.substring(0, idx)] = pair.substring(idx + 1);
  }
  return result;
}

// Jobs — String param for stable FutureProvider.family equality.
final jobsProvider = FutureProvider.family<List<JobPostingModel>, String>(
  (ref, paramsStr) async {
    try {
      final params = _parseParams(paramsStr);
      final res = await ApiService.get(ApiConstants.recruitmentJobs, params: params);
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => JobPostingModel.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  },
);

// Candidates — String param for stable equality.
final candidatesProvider = FutureProvider.family<List<CandidateModel>, String>(
  (ref, paramsStr) async {
    try {
      final params = _parseParams(paramsStr);
      final res = await ApiService.get(ApiConstants.recruitmentCandidates, params: params);
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => CandidateModel.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  },
);

// Interviews — String param for stable equality.
final interviewsProvider = FutureProvider.family<List<InterviewModel>, String>(
  (ref, paramsStr) async {
    try {
      final params = _parseParams(paramsStr);
      final res = await ApiService.get(ApiConstants.recruitmentInterviews, params: params);
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => InterviewModel.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  },
);

class RecruitmentActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> createJob(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.recruitmentJobs, data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> updateCandidateStatus(int id, String status) async {
    state = const AsyncLoading();
    try {
      await ApiService.put('${ApiConstants.recruitmentCandidates}/$id', data: {'status': status});
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> scheduleInterview(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.recruitmentInterviews, data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}

final recruitmentActionsProvider =
    NotifierProvider<RecruitmentActionsNotifier, AsyncValue<void>>(RecruitmentActionsNotifier.new);
