import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/notification_model.dart';

class NotificationsData {
  final List<NotificationModel> items;
  final int unreadCount;

  /// Unread count per menu item — {'pips': 2, 'payslips': 3}. The bell alone
  /// says a number and not where it is, so the same counts also sit on the
  /// menu item each notice belongs to.
  final Map<String, int> areas;

  const NotificationsData({
    required this.items,
    required this.unreadCount,
    this.areas = const {},
  });

  int countFor(String? area) => area == null ? 0 : (areas[area] ?? 0);

  NotificationsData clearArea(String area) => NotificationsData(
        items: items
            .map((n) => n.area == area && !n.read
                ? NotificationModel(
                    id: n.id,
                    type: n.type,
                    area: n.area,
                    title: n.title,
                    body: n.body,
                    actionUrl: n.actionUrl,
                    data: n.data,
                    readAt: DateTime.now().toIso8601String(),
                    createdAt: n.createdAt,
                  )
                : n)
            .toList(),
        unreadCount: (unreadCount - (areas[area] ?? 0)).clamp(0, 1 << 30),
        areas: {...areas}..remove(area),
      );
}

class NotificationsNotifier extends AsyncNotifier<NotificationsData> {
  @override
  Future<NotificationsData> build() => _fetch();

  static Map<String, int> _areasFrom(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
      ..removeWhere((_, v) => v <= 0);
  }

  Future<NotificationsData> _fetch() async {
    try {
      final res = await ApiService.get(ApiConstants.notifications);
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      final items = list.map((j) => NotificationModel.fromJson(j)).toList();
      final unread = body['unread_count'] as int? ?? items.where((n) => !n.read).length;
      return NotificationsData(
        items: items,
        unreadCount: unread,
        areas: _areasFrom(body['areas']),
      );
    } catch (_) {
      return const NotificationsData(items: [], unreadCount: 0);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Quiet refresh — no loading flicker. Used on a timer and after navigating,
  /// where blanking the badges first would look like a glitch.
  Future<void> refreshSilently() async {
    final fresh = await _fetch();
    state = AsyncData(fresh);
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.post(ApiConstants.notificationsRead, data: {'all': true});
      await refreshSilently();
    } catch (_) {}
  }

  /// Opening a screen settles that screen's notices and nothing else — the same
  /// rule the web applies when you navigate to the page. The badge is cleared
  /// locally first so it goes at the moment of the tap rather than after the
  /// round trip.
  Future<void> markAreaRead(String area) async {
    final current = state.valueOrNull;
    if (current == null || current.countFor(area) == 0) return;

    state = AsyncData(current.clearArea(area));

    try {
      await ApiService.post(ApiConstants.notificationsRead, data: {'area': area});
      await refreshSilently();
    } catch (_) {
      // Put the real counts back if the server never heard us.
      await refreshSilently();
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsData>(NotificationsNotifier.new);
