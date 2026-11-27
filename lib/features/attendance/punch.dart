import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/services/location_disclosure.dart';

/// Clock in or out, and always say what happened.
///
/// This exists because the dashboard's button did not.
///
/// `clockIn()` throws an Exception carrying the server's own words — "you are
/// 8.7 km from the site", "already clocked in", whatever it was. The dashboard
/// awaited that call inside an `onTap` with no catch, so the exception became
/// an unhandled async error: Flutter logged it where nobody was looking and
/// the person saw the spinner stop and nothing else.
///
/// That failed quietly for months without a single report, because it only
/// shows when a clock-in is REFUSED. Everybody standing on their site
/// succeeded, the card refreshed, and the absence of a message looked like
/// success. Only the one person being turned away saw nothing at all — and
/// "nothing happens when I press it" is impossible to diagnose, so it was
/// reported as the whole module being broken.
///
/// Every caller goes through here now, so there is one place that can be
/// silent, and it isn't.
Future<void> punchAttendance(
  BuildContext context,
  WidgetRef ref, {
  required bool clockingIn,
}) async {
  if (!await LocationDisclosure.ensure(context,
      purpose: LocationDisclosure.clockIn)) {
    return;
  }

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);

  void say(String text, Color colour) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: colour,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
  }

  try {
    final notifier = ref.read(attendanceTodayProvider.notifier);

    if (clockingIn) {
      await notifier.clockIn();
    } else {
      await notifier.clockOut();
    }

    // Success was silent too. A clock-in is the one action in this app that
    // somebody's pay depends on; it deserves a confirmation they can see.
    say(clockingIn ? 'Clocked in.' : 'Clocked out.', AppColors.success);
  } catch (e) {
    // The server's own wording. It says what to do about a refusal — move
    // closer, turn location on — and paraphrasing it would lose that.
    say(e.toString().replaceFirst('Exception: ', ''), AppColors.error);
  }
}
