import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/bsc_model.dart';

// ─── Cycles list ─────────────────────────────────────────────────────────────

final bscCyclesProvider = FutureProvider.autoDispose<List<BscCycleModel>>((ref) async {
  final resp = await ApiService.get(ApiConstants.bscCycles);
  return (resp.data as List).map((j) => BscCycleModel.fromJson(j)).toList();
});

// ─── My Appraisal ────────────────────────────────────────────────────────────

class MyAppraisalData {
  final BscCycleModel? cycle;
  final List<BscKraWithEntry> kras;
  final double overallScore;

  const MyAppraisalData({this.cycle, this.kras = const [], this.overallScore = 0});
}

final bscMyAppraisalProvider = FutureProvider.autoDispose<MyAppraisalData>((ref) async {
  try {
    final resp = await ApiService.get(ApiConstants.bscMyAppraisal);
    final d    = resp.data as Map<String, dynamic>;

    return MyAppraisalData(
      cycle:        d['cycle'] != null ? BscCycleModel.fromJson(d['cycle']) : null,
      kras:         (d['kras'] as List? ?? []).map((j) => BscKraWithEntry.fromJson(j)).toList(),
      overallScore: (d['overall_score'] as num?)?.toDouble() ?? 0,
    );
  } on DioException catch (e) {
    // 404 → this user has no employee record (e.g. admin-only account).
    // Return empty appraisal data instead of crashing.
    if (e.response?.statusCode == 404) {
      return const MyAppraisalData();
    }
    rethrow;
  }
});

// ─── Team Appraisal ──────────────────────────────────────────────────────────

class TeamAppraisalData {
  final BscCycleModel? cycle;
  final List<BscTeamMember> team;

  const TeamAppraisalData({this.cycle, this.team = const []});
}

final bscTeamAppraisalProvider = FutureProvider.autoDispose<TeamAppraisalData>((ref) async {
  final resp = await ApiService.get(ApiConstants.bscTeamAppraisal);
  final d    = resp.data as Map<String, dynamic>;

  return TeamAppraisalData(
    cycle: d['cycle'] != null ? BscCycleModel.fromJson(d['cycle']) : null,
    team:  (d['team'] as List? ?? []).map((j) => BscTeamMember.fromJson(j)).toList(),
  );
});

// ─── Entry Actions Notifier ───────────────────────────────────────────────────

class BscEntryNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<String> updateEntry(int entryId, Map<String, dynamic> data) async {
    final resp = await ApiService.put('${ApiConstants.bscEntries}/$entryId', data: data);
    ref.invalidate(bscMyAppraisalProvider);
    return resp.data['message'] as String? ?? 'Saved.';
  }

  Future<String> submitEntry(int entryId) async {
    final resp = await ApiService.post('${ApiConstants.bscEntries}/$entryId/submit');
    ref.invalidate(bscMyAppraisalProvider);
    return resp.data['message'] as String? ?? 'Submitted.';
  }

  Future<String> approveEntry(int entryId, {String? comment}) async {
    final resp = await ApiService.post(
      '${ApiConstants.bscEntries}/$entryId/approve',
      data: {if (comment != null) 'appraiser_comment': comment},
    );
    ref.invalidate(bscTeamAppraisalProvider);
    return resp.data['message'] as String? ?? 'Approved.';
  }
}

final bscEntryProvider = NotifierProvider<BscEntryNotifier, void>(BscEntryNotifier.new);
