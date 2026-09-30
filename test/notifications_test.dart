import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/models/notification_model.dart';
import 'package:mastermind_hrms_app/core/providers/notifications_provider.dart';

/// What arrives from /api/notifications, and what the menu does with it.
///
/// `title` and `body` are columns on the server's notifications table, not keys
/// inside `data`. The app read them from `data` only, and the endpoint sent
/// neither, so every notice showed a prettified type string with no message
/// under it. These are the exact shapes the server now sends.
void main() {
  group('NotificationModel', () {
    test('reads the title and body the server actually sends', () {
      final n = NotificationModel.fromJson({
        'id': 706,
        'type': 'pip',
        'area': 'pips',
        'title': 'New file on an improvement plan',
        'body': 'Ashiraf Lule attached "ASHIRAF LULE.pdf" to Loading Errors.',
        'action_url': 'https://mastermind.autos/pips/3',
        'data': {'url': 'https://mastermind.autos/pips/3'},
        'read_at': null,
        'created_at': '2026-09-30 08:05:00',
      });

      expect(n.id, '706');
      expect(n.area, 'pips');
      expect(n.title, 'New file on an improvement plan');
      expect(n.message, contains('ASHIRAF LULE.pdf'));
      expect(n.actionUrl, 'https://mastermind.autos/pips/3');
      expect(n.read, isFalse);
    });

    test('still reads a notice written the older way, with text inside data', () {
      final n = NotificationModel.fromJson({
        'id': 1,
        'type': 'leave_status',
        'data': {'title': 'Leave approved', 'message': 'Your leave was approved.'},
        'created_at': '2026-09-30 08:05:00',
      });

      expect(n.title, 'Leave approved');
      expect(n.message, 'Your leave was approved.');
    });

    test('falls back to a readable version of the type when there is no title', () {
      final n = NotificationModel.fromJson({
        'id': 2,
        'type': 'payroll_processed',
        'data': <String, dynamic>{},
        'created_at': '2026-09-30 08:05:00',
      });

      // Better than showing nothing, and better than "payroll_processed".
      expect(n.title, 'Payroll processed');
      expect(n.message, '');
    });

    test('a read notice knows it has been read', () {
      final n = NotificationModel.fromJson({
        'id': 3,
        'type': 'pip',
        'data': <String, dynamic>{},
        'read_at': '2026-09-30 09:00:00',
        'created_at': '2026-09-30 08:05:00',
      });

      expect(n.read, isTrue);
    });
  });

  group('NotificationsData', () {
    NotificationModel notice(String area, {bool read = false}) => NotificationModel(
          id: '$area-${read ? 'r' : 'u'}',
          type: 'pip',
          area: area,
          title: 'A thing',
          body: 'happened',
          data: const {},
          readAt: read ? '2026-09-30 09:00:00' : null,
          createdAt: '2026-09-30 08:05:00',
        );

    test('counts are looked up by menu area', () {
      const data = NotificationsData(
        items: [],
        unreadCount: 5,
        areas: {'pips': 2, 'payslips': 3},
      );

      expect(data.countFor('pips'), 2);
      expect(data.countFor('payslips'), 3);
      expect(data.countFor('leave'), 0, reason: 'an area with nothing waiting shows no badge');
      expect(data.countFor(null), 0, reason: 'most menu items own no area at all');
    });

    test('opening a screen clears that area and leaves the rest alone', () {
      final data = NotificationsData(
        items: [notice('pips'), notice('pips'), notice('payslips')],
        unreadCount: 3,
        areas: const {'pips': 2, 'payslips': 1},
      );

      final after = data.clearArea('pips');

      expect(after.countFor('pips'), 0);
      expect(after.countFor('payslips'), 1, reason: 'reading your plans says nothing about your pay');
      expect(after.unreadCount, 1);
      expect(after.items.where((n) => n.area == 'pips').every((n) => n.read), isTrue);
      expect(after.items.firstWhere((n) => n.area == 'payslips').read, isFalse);
    });

    test('clearing an area that has nothing in it changes nothing', () {
      const data = NotificationsData(items: [], unreadCount: 2, areas: {'pips': 2});

      final after = data.clearArea('leave');

      expect(after.unreadCount, 2);
      expect(after.countFor('pips'), 2);
    });

    test('the total never goes below zero', () {
      // If the server and the local copy ever disagree, a badge must not end up
      // showing a negative number.
      const data = NotificationsData(items: [], unreadCount: 1, areas: {'pips': 5});

      expect(data.clearArea('pips').unreadCount, 0);
    });
  });
}
