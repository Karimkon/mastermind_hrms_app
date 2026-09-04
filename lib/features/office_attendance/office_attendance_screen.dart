import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/office_attendance_model.dart';
import '../../core/providers/office_attendance_provider.dart';

/// Daily office presence register.
///
/// This is not the payroll attendance screen: nothing recorded here affects
/// anyone's salary. It exists so the office can see who came in, and who did
/// not, including account managers who have no employee record at all.
class OfficeAttendanceScreen extends ConsumerStatefulWidget {
  const OfficeAttendanceScreen({super.key});

  @override
  ConsumerState<OfficeAttendanceScreen> createState() => _OfficeAttendanceScreenState();
}

class _OfficeAttendanceScreenState extends ConsumerState<OfficeAttendanceScreen> {
  DateTime _date = DateTime.now();
  bool _busy = false;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_date);

  Future<void> _punch({required bool clockIn}) async {
    if (_busy) return;
    setState(() => _busy = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = ref.read(officeTodayProvider.notifier);
      final message = clockIn ? await notifier.clockIn() : await notifier.clockOut();
      ref.invalidate(officeRegisterProvider(_dateKey));
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_readableError(e)), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Surface the server's own message rather than a raw Dio dump.
  String _readableError(Object e) {
    final text = e.toString();
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(text);
    return match?.group(1) ?? 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(officeTodayProvider);
    final registerAsync = ref.watch(officeRegisterProvider(_dateKey));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(officeTodayProvider.notifier).refresh();
        ref.invalidate(officeRegisterProvider(_dateKey));
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Header(),
          const SizedBox(height: 16),
          todayAsync.when(
            loading: () => const Card(
              child: Padding(padding: EdgeInsets.all(24), child: LinearProgressIndicator()),
            ),
            error: (e, _) => _ErrorCard(message: _readableError(e)),
            data: (state) => _MyClockCard(
              state: state,
              busy: _busy,
              onClockIn: () => _punch(clockIn: true),
              onClockOut: () => _punch(clockIn: false),
            ),
          ),
          const SizedBox(height: 20),
          registerAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(32), child: CircularProgressIndicator(),
            )),
            error: (e, _) => _ErrorCard(message: _readableError(e)),
            data: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isSupervisor) ...[
                  _SummaryRow(summary: state.summary),
                  const SizedBox(height: 16),
                  _DatePickerRow(
                    date: _date,
                    onPick: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 12),
                ],
                _RegisterList(roster: state.roster),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _FooterNote(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Office Attendance',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary,
                )),
        const SizedBox(height: 4),
        const Text(
          'Daily clock in and out at the head office. Record only — this does not affect pay.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _MyClockCard extends StatelessWidget {
  final OfficeTodayState state;
  final bool busy;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  const _MyClockCard({
    required this.state,
    required this.busy,
    required this.onClockIn,
    required this.onClockOut,
  });

  @override
  Widget build(BuildContext context) {
    final log = state.log;
    final canClockIn = log == null || !log.hasClockedIn;
    final canClockOut = log != null && log.hasClockedIn && log.clockOut == null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE d MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12,
                  letterSpacing: 0.5, fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 10),
            if (log != null && log.hasClockedIn) ...[
              Row(children: [
                _TimeChip(label: 'In', value: log.clockInTime ?? '—', color: AppColors.success),
                const SizedBox(width: 10),
                _TimeChip(
                  label: 'Out',
                  value: log.clockOutTime ?? 'still in',
                  color: log.clockOutTime == null ? AppColors.warning : AppColors.primary,
                ),
                if (log.hours != null) ...[
                  const SizedBox(width: 10),
                  _TimeChip(label: 'Hours', value: '${log.hours}h', color: AppColors.textSecondary),
                ],
              ]),
              if (log.clockInOffsite) ...[
                const SizedBox(height: 10),
                _OffsiteBanner(distance: log.clockInDistanceM),
              ],
            ] else
              const Text('You have not clocked in at the office today.',
                  style: TextStyle(color: AppColors.textSecondary)),

            if (!state.office.hasCoordinates) ...[
              const SizedBox(height: 12),
              const _InfoBanner(
                icon: Icons.location_off_outlined,
                text: 'The office location has not been set yet, so clock-ins '
                    'cannot be checked against it. An administrator can set it '
                    'in Admin → Settings → Attendance.',
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: canClockIn
                  ? FilledButton.icon(
                      onPressed: busy ? null : onClockIn,
                      icon: busy
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login),
                      label: Text(busy ? 'Getting location…' : 'Clock In at Office'),
                    )
                  : canClockOut
                      ? FilledButton.icon(
                          onPressed: busy ? null : onClockOut,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                          icon: busy
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.logout),
                          label: Text(busy ? 'Getting location…' : 'Clock Out'),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Done for today',
                              style: TextStyle(
                                color: AppColors.success, fontWeight: FontWeight.w600,
                              )),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TimeChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _OffsiteBanner extends StatelessWidget {
  final int? distance;
  const _OffsiteBanner({this.distance});

  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      icon: Icons.wrong_location_outlined,
      color: AppColors.warning,
      text: distance == null
          ? 'Recorded as off-site.'
          : 'Recorded as off-site — about ${distance}m from the office.',
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner({required this.icon, required this.text, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final OfficeAttendanceSummary summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Expected', summary.expected, AppColors.primary),
      ('Clocked In', summary.clockedIn, AppColors.success),
      ('Still In', summary.stillIn, AppColors.warning),
      ('No Clock-In', summary.missing, AppColors.error),
      ('Off-site', summary.offsite, AppColors.warning),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tiles
          .map((t) => Container(
                width: 104,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.$2}',
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: t.$3,
                        )),
                    Text(t.$1,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  const _DatePickerRow({required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Text(DateFormat('EEE d MMM yyyy').format(date),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      const Spacer(),
      TextButton.icon(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2024),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (picked != null) onPick(picked);
        },
        icon: const Icon(Icons.edit_calendar_outlined, size: 16),
        label: const Text('Change date'),
      ),
    ]);
  }
}

class _RegisterList extends StatelessWidget {
  final List<OfficeRosterEntry> roster;
  const _RegisterList({required this.roster});

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('Nobody is on the office register for this date.',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    return Column(
      children: roster.map((entry) {
        final log = entry.log;
        final missing = entry.missing;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // A missing clock-in is the thing worth seeing, so it is tinted.
            color: missing ? AppColors.error.withValues(alpha: 0.04) : AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: missing ? AppColors.error.withValues(alpha: 0.20) : AppColors.cardBorder,
            ),
          ),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.userName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (entry.roles.isNotEmpty)
                    Text(entry.roles.join(', '),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                log?.clockInTime == null ? '—' : '${log!.clockInTime} → ${log.clockOutTime ?? '…'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            _StatusPill(entry: entry),
          ]),
        );
      }).toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final OfficeRosterEntry entry;
  const _StatusPill({required this.entry});

  @override
  Widget build(BuildContext context) {
    final log = entry.log;
    late final String label;
    late final Color color;

    if (log == null || !log.hasClockedIn) {
      label = 'No clock-in';
      color = AppColors.error;
    } else if (log.isOpen) {
      label = 'Still in';
      color = AppColors.warning;
    } else {
      label = 'Complete';
      color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 13))),
      ]),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          'This register is for visibility only and is never used to calculate salary. '
          'Client site visits are recorded separately under Site Visits.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ),
    ]);
  }
}
