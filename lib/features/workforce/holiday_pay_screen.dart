import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/workforce_provider.dart';

/// Public holiday pay for a year.
///
/// Two decisions live on this screen and they belong to different people, so the
/// card shows both and never merges them into one verdict:
///
///   * whether the holiday is paid at all — HR's call, and the button only
///     appears when the server says this person may make it
///   * how many people have been marked as having worked it — the account
///     manager's running total
///
/// Payroll pays double only where both are true, which is why an undecided
/// holiday with people marked as having worked it is shown as a warning rather
/// than quietly listed.
class HolidayPayScreen extends ConsumerStatefulWidget {
  const HolidayPayScreen({super.key});

  @override
  ConsumerState<HolidayPayScreen> createState() => _HolidayPayScreenState();
}

class _HolidayPayScreenState extends ConsumerState<HolidayPayScreen> {
  late int _year = DateTime.now().year;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final yearData = ref.watch(holidayPayProvider(_year));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _yearBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(holidayPayProvider(_year)),
              child: yearData.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _retry(() => ref.invalidate(holidayPayProvider(_year))),
                data: (data) => data.holidays.isEmpty
                    ? _empty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: data.holidays.length,
                        itemBuilder: (_, i) =>
                            _holidayCard(data.holidays[i], canDecide: data.canDecide),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _holidayCard(Map<String, dynamic> h, {required bool canDecide}) {
    final decisions = List<Map<String, dynamic>>.from(h['decisions'] ?? []);
    final workedCount = (h['worked_count'] as num?)?.toInt() ?? 0;

    // A single decision with no client is the "everybody" case; anything else is
    // per-client and cannot be summarised in one word.
    final blanket = decisions.where((d) => d['client_id'] == null).firstOrNull;
    final status = blanket?['status']?.toString();

    // The combination that costs money quietly: people marked as having worked a
    // holiday nobody has ruled on. Payroll will pay them at the normal rate.
    final undecidedButWorked = status == null && decisions.isEmpty && workedCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: undecidedButWorked ? AppColors.warning.withValues(alpha: 0.6) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h['name']?.toString() ?? '',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(h['date']?.toString() ?? '',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _decisionChip(status, decisions.length),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                workedCount > 0 ? Icons.groups_rounded : Icons.person_off_outlined,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                workedCount == 0 ? 'Nobody recorded as working' : '$workedCount recorded as working',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (undecidedButWorked) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'People worked this holiday but nobody has decided whether it is paid. '
                'Payroll will pay them at the normal rate until it is decided.',
                style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF92400E)),
              ),
            ),
          ],
          if (canDecide) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: _busy ? null : () => _decide(h, 'rejected'),
                    child: const Text('Not paid'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _decide(h, 'approved'),
                    child: const Text('Pay it'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _decisionChip(String? status, int decisionCount) {
    final (label, bg, fg) = switch (status) {
      'approved' => ('PAID', AppColors.successLight, AppColors.success),
      'rejected' => ('NOT PAID', AppColors.errorLight, AppColors.error),
      _ when decisionCount > 0 => ('$decisionCount CLIENT RULES', AppColors.infoLight, AppColors.info),
      _ => ('UNDECIDED', AppColors.cardBorder, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.3)),
    );
  }

  Future<void> _decide(Map<String, dynamic> h, String status) async {
    final paying = status == 'approved';

    // Confirmed because it is a money decision applied to everybody, and the two
    // buttons sit next to each other.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(paying ? 'Pay this holiday?' : 'Do not pay this holiday?'),
        content: Text(
          paying
              ? 'Everyone recorded as having worked ${h['name']} will be paid at double rate.'
              : '${h['name']} will not attract holiday pay. Anyone who worked it is paid at the normal rate.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(paying ? 'Pay it' : 'Do not pay'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref
        .read(workforceActionsProvider.notifier)
        .decideHoliday(h['id'] as int, status);

    if (!mounted) return;
    setState(() => _busy = false);

    if (saved) {
      ref.invalidate(holidayPayProvider(_year));
      messenger.showSnackBar(SnackBar(
        content: Text('${h['name']} ${paying ? 'will be paid' : 'will not be paid'}.'),
        backgroundColor: AppColors.success,
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('That decision could not be saved.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _empty() => ListView(children: const [
        SizedBox(height: 120),
        Icon(Icons.event_busy_outlined, size: 46, color: AppColors.textMuted),
        SizedBox(height: 14),
        Center(
          child: Text('No public holidays for this year',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ]);

  Widget _retry(VoidCallback onRetry) => ListView(children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted),
        const SizedBox(height: 14),
        const Center(child: Text('Could not load holiday pay')),
        const SizedBox(height: 14),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Try again'))),
      ]);
}
