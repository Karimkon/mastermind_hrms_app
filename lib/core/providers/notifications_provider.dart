import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/notification_model.dart';

class NotificationsData {
  final List<NotificationModel> items;
  final int unreadCount;
  const NotificationsData({required this.items, required this.unreadCount});
}

class NotificationsNotifier extends AsyncNotifier<NotificationsData> {
  @override
  Future<NotificationsData> build() => _fetch();

  Future<NotificationsData> _fetch() async {
    try {
      final res = await ApiService.get(ApiConstants.notifications);
      final body = res.data as Map<String, dynamic>;
      final rawList = body['data'];
      final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
      final items = list.map((j) => NotificationModel.fromJson(j)).toList();
      final unread = body['unread_count'] as int? ?? items.where((n) => !n.read).length;
      return NotificationsData(items: items, unreadCount: unread);
    } catch (_) {
      return const NotificationsData(items: [], unreadCount: 0);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.post(ApiConstants.notificationsRead, data: {'all': true});
      await refresh();
    } catch (_) {}
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsData>(NotificationsNotifier.new);
