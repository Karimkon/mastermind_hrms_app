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

final meetingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, paramsStr) async {
    try {
      final res = await ApiService.get(ApiConstants.meetings, params: _parseStr(paramsStr));
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      return list.map((j) => j as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  },
);

final calendarProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, paramsStr) async {
    try {
      final res = await ApiService.get(ApiConstants.calendar, params: _parseStr(paramsStr));
      final body = res.data as Map<String, dynamic>;
      final List list = body['data'] as List? ?? [];
      return list.map((j) => j as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  },
);

class MeetingActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> createMeeting(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ApiService.post(ApiConstants.meetings, data: data);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> rsvp(int meetingId, String response) async {
    state = const AsyncLoading();
    try {
      await ApiService.post('${ApiConstants.meetings}/$meetingId/rsvp', data: {'response': response});
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}

final meetingActionsProvider =
    NotifierProvider<MeetingActionsNotifier, AsyncValue<void>>(MeetingActionsNotifier.new);
