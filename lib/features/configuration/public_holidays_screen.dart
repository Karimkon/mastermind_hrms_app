import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/configuration_provider.dart';

/// The public holiday calendar, one year at a time.
///
/// A once-a-year job, which is why the seed button exists: entering nine fixed
/// dates by hand on a phone is the sort of task that gets postponed until the
/// January payroll is already wrong.
///
/// The calendar decides pay in two directions — monthly staff have holidays
/// counted toward their worked days, casual staff earn double for an approved one
/// they worked — so a holiday that has been used stops being deletable, and the
/// row says so rather than offering a delete that will be refused.
class PublicHolidaysScreen extends ConsumerStatefulWidget {
  const PublicHolidaysScreen({super.key});

  @override
  ConsumerState<PublicHolidaysScreen> createState() => _PublicHolidaysScreenState();
}

class _PublicHolidaysScreenState extends ConsumerState<PublicHolidaysScreen> {
  late int _year = DateTime.now().year;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(publicHolidaysProvider(_year));

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: year.maybeWhen(
        data: (d) => d.canManage
            ? FloatingActionButton.extended(
                onPressed: _busy ? null : _addHoliday,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add holiday'),
              )
            : null,
        orElse: () => null,
      ),
      body: Column(
        children: [
          _yearBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(publicHolidaysProvider(_year)),
              child: year.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  const SizedBox(height: 110),
                  const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted),
                  const SizedBox(height: 14),
                  const Center(child: Text('Could not load the calendar')),
                  const SizedBox(height: 14),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => ref.invalidate(publicHolidaysProvider(_year)),
                      child: const Text('Try again'),
                    ),
                  ),
                ]),
                data: (d) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                  children: [
                    if (d.canManage && d.missingFixed > 0) _seedCard(d.missingFixed),
                    if (d.holidays.isEmpty && d.missingFixed == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 90),
                        child: Column(children: [
                          Icon(Icons.event_note_rounded, size: 46, color: AppColors.textMuted),
                          SizedBox(height: 14),
                          Text('No holidays for this year',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ...d.holidays.map((h) => _HolidayRow(
                          holiday: h,
                          canManage: d.canManage,
                          busy: _busy,
                          onDelete: () => _delete(h),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous year',
          ),
          Expanded(
            child: Text('$_year',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            onPressed: () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next year',
          ),
        ],
      ),
    );
  }

  /// Offered only when something is actually missing, and it says how many.
  Widget _seedCard(int missing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('$_year is missing $missing fixed holiday${missing == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Christmas, Independence Day and the rest fall on the same date every '
            'year and can be filled in at once. Easter and the Eids move, so those '
            'still need adding by hand.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _seed,
              child: Text('Fill in the $missing fixed date${missing == 1 ? '' : 's'}'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seed() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    final result = await ref.read(holidayCalendarActionsProvider.notifier).seed(_year);

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.error != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(result.error!), backgroundColor: AppColors.error));
      return;
    }

    ref.invalidate(publicHolidaysProvider(_year));

    // The note is shown rather than swallowed: somebody who sees nine holidays
    // appear may reasonably believe the year is now complete, and it is not.
    messenger.showSnackBar(SnackBar(
      content: Text('${result.added} added. ${result.note}'),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 6),
    ));
  }

  Future<void> _addHoliday() async {
    final name = TextEditingController();
    DateTime? date;
    String type = 'national';
    bool isPaid = true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add a public holiday',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Name', hintText: 'Eid al-Fitr', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime(_year, 1, 1),
                      // Confined to the year being edited, so a mis-tap cannot
                      // quietly file the holiday under a different one.
                      firstDate: DateTime(_year, 1, 1),
                      lastDate: DateTime(_year, 12, 31),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Date', border: OutlineInputBorder()),
                    child: Text(
                      date == null
                          ? 'Pick a date in $_year'
                          : DateFormat('EEEE, d MMMM yyyy').format(date!),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: date == null ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (date != null &&
                    (date!.weekday == DateTime.saturday || date!.weekday == DateTime.sunday)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
                    child: const Text(
                      'That is a weekend. Most staff do not work it, so it will change little.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'national', label: Text('National')),
                    ButtonSegment(value: 'religious', label: Text('Religious')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setSheet(() => type = s.first),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isPaid,
                  onChanged: (v) => setSheet(() => isPaid = v),
                  title: const Text('Paid holiday', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Counts toward pay for monthly staff',
                      style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (name.text.trim().isEmpty || date == null)
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: const Text('Add holiday'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    final error = await ref.read(holidayCalendarActionsProvider.notifier).add(
          date: DateFormat('yyyy-MM-dd').format(date!),
          name: name.text.trim(),
          type: type,
          isPaid: isPaid,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error == null) {
      ref.invalidate(publicHolidaysProvider(_year));
      messenger.showSnackBar(const SnackBar(
          content: Text('Holiday added.'), backgroundColor: AppColors.success));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
  }

  Future<void> _delete(Map<String, dynamic> holiday) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this holiday?'),
        content: Text('${holiday['name']} will be taken off the $_year calendar.',
            style: const TextStyle(fontSize: 13.5, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    final error =
        await ref.read(holidayCalendarActionsProvider.notifier).remove(holiday['id'] as int);

    if (!mounted) return;
    setState(() => _busy = false);

    if (error == null) {
      ref.invalidate(publicHolidaysProvider(_year));
      messenger.showSnackBar(const SnackBar(
          content: Text('Holiday removed.'), backgroundColor: AppColors.success));
    } else {
      // The server explains exactly what the holiday carries. That sentence is
      // the useful part, so it is shown long enough to read.
      messenger.showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 7),
      ));
    }
  }
}

class _HolidayRow extends StatelessWidget {
  final Map<String, dynamic> holiday;
  final bool canManage;
  final bool busy;
  final VoidCallback onDelete;

  const _HolidayRow({
    required this.holiday,
    required this.canManage,
    required this.busy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final weekend = holiday['falls_on_weekend'] == true;
    final inUse = holiday['in_use'] == true;
    final religious = holiday['type'] == 'religious';
    final date = DateTime.tryParse(holiday['date']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // The day of the month, large, because a calendar is read by date.
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: weekend ? AppColors.surface : AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(date == null ? '—' : DateFormat('d').format(date),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: weekend ? AppColors.textMuted : AppColors.primary)),
                const SizedBox(height: 2),
                Text(date == null ? '' : DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: weekend ? AppColors.textMuted : AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(holiday['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(holiday['day_of_week']?.toString() ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (religious) ...[
                      const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                      const Text('Religious',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                    if (holiday['is_paid'] != true) ...[
                      const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                      const Text('Unpaid',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
                    ],
                  ],
                ),
                if (inUse) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      // Said plainly rather than offering a delete that will be
                      // refused with a paragraph of explanation.
                      const Text('Used in payroll — cannot be removed',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (canManage && !inUse)
            IconButton(
              onPressed: busy ? null : onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppColors.error,
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}
