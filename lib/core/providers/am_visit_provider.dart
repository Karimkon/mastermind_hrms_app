import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/am_visit_model.dart';

// ─── Clients list ────────────────────────────────────────────────────────────

final amVisitClientsProvider = FutureProvider.autoDispose<List<AmVisitClientModel>>((ref) async {
  final resp = await ApiService.get(ApiConstants.amVisitClients);
  return (resp.data as List).map((j) => AmVisitClientModel.fromJson(j)).toList();
});

// ─── Active sessions ─────────────────────────────────────────────────────────

final amVisitActiveProvider = FutureProvider.autoDispose<List<AmVisitSessionModel>>((ref) async {
  final resp = await ApiService.get(ApiConstants.amVisitActive);
  return (resp.data as List).map((j) => AmVisitSessionModel.fromJson(j)).toList();
});

// ─── History (paginated) ─────────────────────────────────────────────────────

class AmVisitHistoryState {
  final List<AmVisitSessionModel> items;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int lastPage;

  const AmVisitHistoryState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.lastPage = 1,
  });

  AmVisitHistoryState copyWith({
    List<AmVisitSessionModel>? items,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? lastPage,
  }) =>
      AmVisitHistoryState(
        items:       items       ?? this.items,
        isLoading:   isLoading   ?? this.isLoading,
        error:       error,
        currentPage: currentPage ?? this.currentPage,
        lastPage:    lastPage    ?? this.lastPage,
      );
}

class AmVisitNotifier extends AsyncNotifier<AmVisitHistoryState> {
  @override
  Future<AmVisitHistoryState> build() async => _fetch(1);

  Future<AmVisitHistoryState> _fetch(int page) async {
    final resp = await ApiService.get('${ApiConstants.amVisits}?per_page=20&page=$page');
    final d    = resp.data as Map<String, dynamic>;
    return AmVisitHistoryState(
      items:       (d['data'] as List).map((j) => AmVisitSessionModel.fromJson(j)).toList(),
      currentPage: d['current_page'] ?? 1,
      lastPage:    d['last_page'] ?? 1,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(1));
  }

  Future<String> clockIn({
    required int clientId,
    required double lat,
    required double lng,
    String? notes,
  }) async {
    final resp = await ApiService.post(ApiConstants.amVisitClockIn, data: {
      'client_id': clientId,
      'lat':       lat,
      'lng':       lng,
      if (notes != null) 'notes': notes,
    });
    await refresh();
    final message = resp.data['message'] as String? ?? 'Clocked in.';
    final geoWarning = resp.data['geo_warning'] as String?;
    return geoWarning != null ? '$message\nNote: $geoWarning' : message;
  }

  Future<String> clockOut({
    required int sessionId,
    double? lat,
    double? lng,
    String? notes,
  }) async {
    final resp = await ApiService.post(ApiConstants.amVisitClockOut, data: {
      'session_id': sessionId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (notes != null) 'notes': notes,
    });
    await refresh();
    return resp.data['message'] as String? ?? 'Clocked out.';
  }
}

final amVisitProvider = AsyncNotifierProvider<AmVisitNotifier, AmVisitHistoryState>(
  AmVisitNotifier.new,
);
