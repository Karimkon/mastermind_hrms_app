import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/overtime_model.dart';
import '../../core/providers/overtime_provider.dart';

/// HR / Admin sign-off on overtime.
///
/// Payroll pays approved hours only, so nothing on this screen is cosmetic:
/// leaving a record pending means that overtime is never paid.
class OvertimeScreen extends ConsumerStatefulWidget {
  const OvertimeScreen({super.key});

  @override
  ConsumerState<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends ConsumerState<OvertimeScreen> {
  String _status = 'pending';

  String _readableError(Object e) {
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(e.toString());
    return match?.group(1) ?? 'Something went wrong. Please try again.';
  }

  Future<void> _decide(OvertimeModel row, OvertimePolicy policy) async {
    final result = await showDialog<_Decision>(
      context: context,
      builder: (_) => _DecisionDialog(row: row, policy: policy),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = ref.read(overtimeProvider.notifier);
      final message = result.approve
          ? await notifier.approve(row.id, result.hours, note: result.note)
          : await notifier.reject(row.id, note: result.note);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_readableError(e)), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(overtimeProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(overtimeProvider.notifier).refresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(padding: const EdgeInsets.all(20), children: [
          _Banner(
            icon: Icons.error_outline,
            color: AppColors.error,
            text: _readableError(e),
          ),
        ]),
        data: (state) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Overtime Approval',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: AppColors.textPrimary,
                    )),
            const SizedBox(height: 4),
            Text(
              'Overtime is paid only once approved here. Policy is '
              '${state.policy.dailyCap.toStringAsFixed(0)}h a day, '
              '${state.policy.weeklyCap.toStringAsFixed(0)}h a week.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            _Banner(
              icon: Icons.info_outline,
              color: AppColors.primary,
              text: '${state.pendingTotal} record(s) are waiting for a decision. '
                  'Hours above the policy are highlighted, but you can still approve them.',
            ),
            const SizedBox(height: 14),
            _StatusTabs(
              current: _status,
              onChanged: (s) {
                setState(() => _status = s);
                ref.read(overtimeProvider.notifier).setStatus(s);
              },
            ),
            const SizedBox(height: 14),
            if (state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.timer_outlined, size: 40, color: AppColors.textMuted),
                    SizedBox(height: 10),
                    Text('No overtime records in this period.',
                        style: TextStyle(color: AppColors.textSecondary)),
                    SizedBox(height: 4),
                    Text('Overtime appears when someone clocks out after more than 8 hours.',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        textAlign: TextAlign.center),
                  ]),
                ),
              )
            else
              ...state.items.map((row) => _OvertimeCard(
                    row: row,
                    policy: state.policy,
                    onDecide: () => _decide(row, state.policy),
                  )),
          ],
        ),
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _StatusTabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = {
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'all': 'All',
    };

    return Wrap(
      spacing: 8,
      children: options.entries.map((e) {
        final selected = current == e.key;
        return ChoiceChip(
          label: Text(e.value),
          selected: selected,
          onSelected: (_) => onChanged(e.key),
        );
      }).toList(),
    );
  }
}

class _OvertimeCard extends StatelessWidget {
  final OvertimeModel row;
  final OvertimePolicy policy;
  final VoidCallback onDecide;

  const _OvertimeCard({required this.row, required this.policy, required this.onDecide});

  @override
  Widget build(BuildContext context) {
    final flagged = row.breachesPolicy;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: flagged ? AppColors.warning.withValues(alpha: 0.05) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: flagged ? AppColors.warning.withValues(alpha: 0.35) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.employeeName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    [
                      if (row.empNumber != null) row.empNumber!,
                      if (row.clientName != null) row.clientName!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            _StatusBadge(row: row),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _Metric(
              label: 'Date',
              value: _formatDate(row.date),
              color: AppColors.textSecondary,
            ),
            _Metric(
              label: 'Recorded',
              value: '${row.recordedHours.toStringAsFixed(2)}h',
              color: row.exceedsDaily ? AppColors.warning : AppColors.textPrimary,
              warn: row.exceedsDaily,
            ),
            _Metric(
              label: 'Week',
              value: '${row.weekTotal.toStringAsFixed(2)}h',
              color: row.exceedsWeekly ? AppColors.warning : AppColors.textSecondary,
              warn: row.exceedsWeekly,
            ),
            if (row.isApproved)
              _Metric(
                label: 'Approved',
                value: '${row.approvedHours.toStringAsFixed(2)}h',
                color: AppColors.success,
              ),
          ]),
          if (row.note != null && row.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(row.note!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
          if (row.approver != null) ...[
            const SizedBox(height: 4),
            Text('Decided by ${row.approver}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
          if (row.isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDecide,
                icon: const Icon(Icons.gavel_outlined, size: 16),
                label: const Text('Approve or reject'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('EEE d MMM').format(parsed);
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool warn;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          Row(children: [
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color,
                  )),
            ),
            if (warn) const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.warning),
            ),
          ]),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OvertimeModel row;
  const _StatusBadge({required this.row});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (row.status) {
      'approved' => ('Approved', AppColors.success),
      'rejected' => ('Rejected', AppColors.error),
      _ => ('Pending', AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _Decision {
  final bool approve;
  final double hours;
  final String? note;

  const _Decision({required this.approve, required this.hours, this.note});
}

class _DecisionDialog extends StatefulWidget {
  final OvertimeModel row;
  final OvertimePolicy policy;

  const _DecisionDialog({required this.row, required this.policy});

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  late final TextEditingController _hoursCtrl;
  final _noteCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to the policy cap so the safe choice is one tap, while still
    // allowing more to be typed in deliberately.
    final suggested = widget.row.recordedHours <= widget.policy.dailyCap
        ? widget.row.recordedHours
        : widget.policy.dailyCap;
    _hoursCtrl = TextEditingController(text: suggested.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit(bool approve) {
    if (!approve) {
      Navigator.pop(context, _Decision(approve: false, hours: 0, note: _noteCtrl.text));
      return;
    }

    final hours = double.tryParse(_hoursCtrl.text.trim());
    if (hours == null || hours < 0 || hours > 24) {
      setState(() => _error = 'Enter a number of hours between 0 and 24.');
      return;
    }

    Navigator.pop(context, _Decision(approve: true, hours: hours, note: _noteCtrl.text));
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;

    return AlertDialog(
      title: Text(row.employeeName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recorded: ${row.recordedHours.toStringAsFixed(2)}h  ·  '
                'Week so far: ${row.weekTotal.toStringAsFixed(2)}h',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (row.breachesPolicy) ...[
              const SizedBox(height: 10),
              _Banner(
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                text: 'Above the policy of '
                    '${widget.policy.dailyCap.toStringAsFixed(0)}h a day / '
                    '${widget.policy.weeklyCap.toStringAsFixed(0)}h a week. '
                    'You can still approve it.',
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _hoursCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Hours to approve',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLength: 255,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => _submit(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Reject'),
        ),
        FilledButton(onPressed: () => _submit(true), child: const Text('Approve')),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Banner({required this.icon, required this.color, required this.text});

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
