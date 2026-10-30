import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/office_attendance_provider.dart';
import '../../core/services/geo_fence.dart';

/// Clock in at head office, from the dashboard, without going hunting for it.
///
/// Office-based staff — account managers, HR, finance, the MD — work out of
/// Kisaasi rather than at a client site, and their register lives two taps
/// away under Office Attendance. The clock-in they perform every single
/// morning was the one thing not on the screen they open every morning.
///
/// It appears only when there is something to do:
///   - the person holds an office-based role
///   - head office has coordinates configured
///   - they are inside the radius
///   - they have not already finished for the day
///
/// Away from the office it shows how far, rather than vanishing silently —
/// somebody who expects the button and cannot find it needs to be told why.
class OfficeClockButton extends ConsumerStatefulWidget {
  final UserModel user;

  const OfficeClockButton({super.key, required this.user});

  /// Who works out of head office. Site staff clock in against their client's
  /// fence instead, on the Attendance screen, and must not be offered this.
  static const officeRoles = [
    'account-manager',
    'hr-admin',
    'super-admin',
    'manager',
    'payroll-officer',
    'recruiter',
    'quality-manager',
    'auditor',
  ];

  static bool appliesTo(UserModel user) => user.hasAnyRole(officeRoles);

  @override
  ConsumerState<OfficeClockButton> createState() => _OfficeClockButtonState();
}

class _OfficeClockButtonState extends ConsumerState<OfficeClockButton>
    with SingleTickerProviderStateMixin {
  Position? _fix;
  bool _locating = false;
  bool _working = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    // A slow breath on the ring, only while the button is actionable. Motion
    // that never stops is noise; motion that means "this is live" is not.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      // Never prompts for permission here. Asking to track somebody the
      // instant they open the dashboard is how an app gets denied location
      // for good; the clock-in flow itself does the asking, with a reason.
      if (await Geolocator.checkPermission() case LocationPermission.denied ||
          LocationPermission.deniedForever) {
        return;
      }

      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) setState(() => _fix = fix);
    } catch (_) {
      // No fix is a state, not an error. The card says so.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _punch({required bool clockingIn}) async {
    setState(() => _working = true);

    try {
      final notifier = ref.read(officeTodayProvider.notifier);
      final message =
          clockingIn ? await notifier.clockIn() : await notifier.clockOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ));
    } catch (e) {
      if (!mounted) return;

      // The server's own wording. It explains what to do about a refusal -
      // turn location on, or move closer - and paraphrasing it would lose that.
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!OfficeClockButton.appliesTo(widget.user)) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(officeTodayProvider);

    return state.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (today) {
        final office = today.office;

        // Nothing configured means nothing to stand inside. Rather than show
        // a button that always fails, show nothing.
        if (!office.hasCoordinates || office.lat == null || office.lng == null) {
          return const SizedBox.shrink();
        }

        final log = today.log;
        final clockedIn = log?.clockIn != null && log?.clockOut == null;
        final finished = log?.clockOut != null;

        final radius = office.radius ?? 150;
        final metres = _fix == null
            ? null
            : metresBetween(
                _fix!.latitude, _fix!.longitude, office.lat!, office.lng!);
        final inside = metres != null && metres <= radius;

        return _Card(
          clockedIn: clockedIn,
          finished: finished,
          inside: inside,
          locating: _locating,
          working: _working,
          metres: metres,
          radius: radius,
          clockInAt: log?.clockIn,
          clockOutAt: log?.clockOut,
          pulse: _pulse,
          onRetryLocation: _locate,
          onPunch: () => _punch(clockingIn: !clockedIn),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final bool clockedIn;
  final bool finished;
  final bool inside;
  final bool locating;
  final bool working;
  final double? metres;
  final double radius;
  final String? clockInAt;
  final String? clockOutAt;
  final Animation<double> pulse;
  final VoidCallback onRetryLocation;
  final VoidCallback onPunch;

  const _Card({
    required this.clockedIn,
    required this.finished,
    required this.inside,
    required this.locating,
    required this.working,
    required this.metres,
    required this.radius,
    required this.clockInAt,
    required this.clockOutAt,
    required this.pulse,
    required this.onRetryLocation,
    required this.onPunch,
  });

  String get _distance => metres == null
      ? ''
      : metres! >= 1000
          ? '${(metres! / 1000).toStringAsFixed(1)} km'
          : '${metres!.round()} m';

  @override
  Widget build(BuildContext context) {
    final (accent, tint) = finished
        ? (AppColors.info, AppColors.infoLight)
        : clockedIn
            ? (AppColors.error, AppColors.errorLight)
            : inside
                ? (AppColors.success, AppColors.successLight)
                : (AppColors.textSecondary, AppColors.surface);

    final actionable = !finished && (inside || clockedIn);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _Dial(
            accent: accent,
            tint: tint,
            enabled: actionable && !working,
            working: working,
            pulse: pulse,
            icon: finished
                ? Icons.check_rounded
                : clockedIn
                    ? Icons.logout_rounded
                    : Icons.fingerprint_rounded,
            onTap: actionable && !working ? onPunch : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  finished
                      ? 'Done for today'
                      : clockedIn
                          ? 'Tap to clock out'
                          : inside
                              ? 'Tap to clock in'
                              : locating
                                  ? 'Finding you…'
                                  : 'Head office',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!inside && !finished && !locating) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onRetryLocation,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh_rounded, size: 13, color: accent),
                      const SizedBox(width: 4),
                      Text('Check again',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    if (finished) {
      return 'In at $clockInAt · out at $clockOutAt.';
    }
    if (clockedIn) {
      return 'Clocked in at $clockInAt.';
    }
    if (locating) {
      return 'Checking whether you are at the office.';
    }
    if (metres == null) {
      return 'Your location is not available, so this cannot be checked.';
    }
    if (inside) {
      return 'You are $_distance from the office, inside the ${radius.round()} m range.';
    }
    return 'You are $_distance away. Clock in when you are within ${radius.round()} m.';
  }
}

/// The dial itself: a ring that breathes while it can be used, and sits
/// still when it cannot.
class _Dial extends StatelessWidget {
  final Color accent;
  final Color tint;
  final bool enabled;
  final bool working;
  final Animation<double> pulse;
  final IconData icon;
  final VoidCallback? onTap;

  const _Dial({
    required this.accent,
    required this.tint,
    required this.enabled,
    required this.working,
    required this.pulse,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = enabled ? pulse.value : 0.0;

        return SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The halo only exists while the button is live.
              if (enabled)
                Container(
                  width: 62 + (14 * t),
                  height: 62 + (14 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12 * (1 - t)),
                  ),
                ),
              child!,
            ],
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: enabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
                    )
                  : null,
              color: enabled ? null : tint,
              border: enabled ? null : Border.all(color: AppColors.cardBorder),
            ),
            child: working
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    size: 28,
                    color: enabled ? Colors.white : accent,
                  ),
          ),
        ),
      ),
    );
  }
}
