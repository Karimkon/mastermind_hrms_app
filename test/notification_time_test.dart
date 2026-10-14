import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/models/notification_model.dart';

/// "3h ago" on a message sent one minute earlier.
///
/// `DateTime.parse` reads a string with no zone marker as LOCAL time. The
/// server stores UTC and the phones are on EAT (UTC+3), so a bare
/// "2026-10-13 14:26:00" was taken as 14:26 EAT against a clock reading 17:26.
/// Every timestamp in the app was stale by exactly the offset -- which is the
/// tell: three hours is not drift, it is a missing zone.
///
/// The API now sends ISO 8601 with the offset. These tests also cover the bare
/// form, because phones that have not updated still receive it and because
/// assuming UTC there is what makes the app right either way.
NotificationModel at(String createdAt) => NotificationModel(
      id: '1',
      type: 'message_received',
      title: 'New message',
      body: 'System Admin: System ready over',
      data: const {},
      createdAt: createdAt,
    );

void main() {
  group('timeAgo', () {
    test('a notice sent seconds ago reads as just now, not hours', () {
      final sentNow = DateTime.now().toUtc();
      expect(at(sentNow.toIso8601String()).timeAgo, 'just now');
    });

    test('an unzoned server timestamp is treated as UTC, not local', () {
      // The exact shape the old API sent. Formatted without a zone, it must
      // still be read as the instant it actually was.
      final sentNow = DateTime.now().toUtc();
      final bare = '${sentNow.year.toString().padLeft(4, '0')}-'
          '${sentNow.month.toString().padLeft(2, '0')}-'
          '${sentNow.day.toString().padLeft(2, '0')} '
          '${sentNow.hour.toString().padLeft(2, '0')}:'
          '${sentNow.minute.toString().padLeft(2, '0')}:'
          '${sentNow.second.toString().padLeft(2, '0')}';

      expect(at(bare).timeAgo, 'just now',
          reason: 'an unzoned timestamp must not be read as local time');
    });

    test('a Z-suffixed timestamp works', () {
      final sentNow = DateTime.now().toUtc();
      final z = '${sentNow.toIso8601String().split('.').first}Z';
      expect(at(z).timeAgo, 'just now');
    });

    test('an explicit +03:00 offset is honoured', () {
      final kampalaNow = DateTime.now().toUtc().add(const Duration(hours: 3));
      final s = kampalaNow.toIso8601String().split('.').first;
      expect(at('$s+03:00').timeAgo, 'just now');
    });

    test('real ages are still reported', () {
      final twoHours = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      expect(at(twoHours.toIso8601String()).timeAgo, '2h ago');

      final threeDays = DateTime.now().toUtc().subtract(const Duration(days: 3));
      expect(at(threeDays.toIso8601String()).timeAgo, '3d ago');

      final tenMinutes = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
      expect(at(tenMinutes.toIso8601String()).timeAgo, '10m ago');
    });

    test('a clock running behind the server never reads as the future', () {
      final slightlyAhead = DateTime.now().toUtc().add(const Duration(minutes: 2));
      expect(at(slightlyAhead.toIso8601String()).timeAgo, 'just now');
    });

    test('an unparseable value is empty rather than a crash', () {
      expect(at('not a date').timeAgo, '');
      expect(at('').timeAgo, '');
    });

    test('createdAtUtc returns a UTC instant whatever the input shape', () {
      final sent = DateTime.utc(2026, 10, 13, 14, 26, 0);

      for (final shape in [
        '2026-10-13 14:26:00',
        '2026-10-13T14:26:00Z',
        '2026-10-13T14:26:00+00:00',
        '2026-10-13T17:26:00+03:00',
      ]) {
        final got = at(shape).createdAtUtc;
        expect(got, isNotNull, reason: shape);
        expect(got!.isUtc, isTrue, reason: shape);
        expect(got.isAtSameMomentAs(sent), isTrue,
            reason: '$shape resolved to $got, expected $sent');
      }
    });
  });
}
