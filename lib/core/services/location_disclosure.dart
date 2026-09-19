import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';

/// Tells somebody what their location is for, before anything asks for it.
///
/// Google Play requires a prominent in-app disclosure before the runtime
/// permission prompt for location: it has to say what is collected, what it is
/// used for, and be dismissible only by a deliberate choice. An app that goes
/// straight to the system prompt is rejected, and for an HR app that records
/// where staff are standing, that rejection would be fair.
///
/// It is also the decent thing to do. Somebody clocking in is being asked to
/// hand their employer their position; they should be told that in a sentence
/// they can read, not have it inferred from a system dialog that says only
/// "Allow Mastermind HRMS to access this device's location?".
///
/// Shown once and remembered. Asking again on every clock-in would train people
/// to tap through it, which defeats the point.
class LocationDisclosure {
  static const _key = 'location_disclosure_accepted_v1';

  /// Whether location may now be requested.
  ///
  /// Returns true without showing anything when permission is already granted —
  /// the disclosure exists to precede the system prompt, and there is no prompt
  /// left to precede. Returns false if the person declines, and the caller must
  /// then not request permission at all.
  static Future<bool> ensure(BuildContext context, {required String purpose}) async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return true;
    }

    // Permanently denied: the system will not prompt again, so a disclosure
    // ahead of a prompt that cannot happen is just a dialog in the way. The
    // caller's own message about device settings is the useful one.
    if (permission == LocationPermission.deniedForever) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_key) == true) {
      return true;
    }

    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      // Deliberately not dismissible by tapping outside. Play asks for an
      // affirmative action, and a dialog you can wave away has not disclosed
      // anything.
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 30),
        title: const Text(
          'Why this app needs your location',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              purpose,
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            // The three facts Play asks to be stated plainly, and that somebody
            // handing over their position is entitled to know.
            _Point(
              icon: Icons.my_location_rounded,
              text: 'Your position is recorded at the moment you tap, and not at '
                  'any other time.',
            ),
            _Point(
              icon: Icons.phonelink_off_rounded,
              text: 'The app never collects your location in the background or '
                  'while it is closed.',
            ),
            _Point(
              icon: Icons.business_center_rounded,
              text: 'It is stored against that record and visible to your HR and '
                  'payroll team.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      // Remembered only on acceptance. Somebody who declines is asked again next
      // time rather than being locked out of a feature by one tap.
      await prefs.setBool(_key, true);

      return true;
    }

    return false;
  }

  /// Purpose lines, kept together so the wording cannot drift between screens.
  static const clockIn =
      'Mastermind HRMS records where you are when you clock in or out, so your '
      'attendance can be confirmed against the site you are assigned to.';

  static const siteVisit =
      'Mastermind HRMS records where you are when you start and end a site visit, '
      'so the visit can be confirmed against the client you are visiting.';
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
