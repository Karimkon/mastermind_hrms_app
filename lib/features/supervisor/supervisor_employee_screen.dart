import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/supervisor_model.dart';
import '../../core/providers/supervisor_provider.dart';
import '../../core/widgets/ui.dart';

/// One person at the supervised site, and the only place their details can
/// be changed from the phone.
///
/// "Changed" is the wrong word and the screen says so. Saving writes a
/// request; the account manager decides it; the supervisor cannot take it
/// back. That is stated before the form, again above the button, and the
/// form locks itself while something is waiting.
class SupervisorEmployeeScreen extends ConsumerWidget {
  final int employeeId;
  const SupervisorEmployeeScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supervisorEmployeeProvider(employeeId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Employee')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: EdgeInsets.all(AppSpace.page(context)),
          children: [
            EmptyState(
              icon: Icons.person_off_rounded,
              title: 'Could not open this person',
              detail: e.toString().replaceFirst('Exception: ', ''),
              action: FilledButton(
                onPressed: () => ref.invalidate(supervisorEmployeeProvider(employeeId)),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(supervisorEmployeeProvider(employeeId)),
          child: ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: [
              _Header(employee: detail.employee),
              const SizedBox(height: AppSpace.xl),
              const SectionLabel('Still working?'),
              _StoppedWorkingCard(employee: detail.employee),
              const SizedBox(height: AppSpace.xl),
              const SectionLabel('Details'),
              _ProposeForm(employeeId: employeeId, contract: detail.editable),
              const SizedBox(height: AppSpace.xl),
              const SectionLabel('Recent attendance'),
              _Attendance(rows: detail.recentAttendance),
              const SizedBox(height: AppSpace.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recording that somebody has stopped working.
///
/// The one thing on this screen that is NOT a proposal. A man who left on
/// Monday is ticked present on Tuesday out of habit and paid on Friday, and
/// the people who could stop it are miles away and have not been told. So
/// this writes immediately, takes them off the register and the payroll, and
/// notifies the account manager, who can put it back.
class _StoppedWorkingCard extends ConsumerStatefulWidget {
  final SupervisorEmployeeModel employee;
  const _StoppedWorkingCard({required this.employee});

  @override
  ConsumerState<_StoppedWorkingCard> createState() => _StoppedWorkingCardState();
}

class _StoppedWorkingCardState extends ConsumerState<_StoppedWorkingCard> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.employee.statusLabel;

    if (label != null) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.person_off_rounded, size: 18, color: AppColors.textMuted),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                '$label — off the register and off the payroll. '
                'Ask your account manager to put them back.',
                style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'If this person has left, been stood down or is on hold, record it here. '
            'It stops their attendance and their pay today and tells your account manager.',
            style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.md),
          OutlinedButton.icon(
            onPressed: _sending ? null : _record,
            icon: const Icon(Icons.person_off_rounded, size: 17),
            label: Text(_sending ? 'Recording…' : 'They have stopped working'),
          ),
        ],
      ),
    );
  }

  Future<void> _record() async {
    final choices = await SupervisorActions.statusChoices();
    if (!mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _StoppedWorkingDialog(choices: choices, name: widget.employee.name),
    );

    if (result == null || !mounted) return;

    setState(() => _sending = true);

    final message = await SupervisorActions.recordStatus(
      widget.employee.id,
      state: result['state']!,
      reason: result['reason']!,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message ?? 'Recorded.'),
      backgroundColor: message == null ? AppColors.error : AppColors.success,
    ));

    ref.invalidate(supervisorEmployeeProvider(widget.employee.id));
    ref.invalidate(supervisorWorkforceProvider(''));
  }
}

class _StoppedWorkingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> choices;
  final String name;
  const _StoppedWorkingDialog({required this.choices, required this.name});

  @override
  State<_StoppedWorkingDialog> createState() => _StoppedWorkingDialogState();
}

class _StoppedWorkingDialogState extends State<_StoppedWorkingDialog> {
  String? _state;
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.choices.map((c) => RadioListTile<String>(
                  value: c['value'] as String,
                  groupValue: _state,
                  onChanged: (v) => setState(() => _state = v),
                  title: Text(c['label'] as String, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(c['hint'] as String, style: const TextStyle(fontSize: 11.5)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
            const SizedBox(height: AppSpace.sm),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'e.g. Absconded — last on site 12 Nov, phone off since.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          // Both are required by the server too; checking here saves a round
          // trip and says which one is missing.
          onPressed: _state == null || _reasonCtrl.text.trim().length < 5
              ? null
              : () => Navigator.pop(context, {'state': _state!, 'reason': _reasonCtrl.text.trim()}),
          child: const Text('Record it'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final SupervisorEmployeeModel employee;
  const _Header({required this.employee});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee.name,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              [
                employee.staffNumber,
                if ((employee.designation ?? '').isNotEmpty) employee.designation!,
                if ((employee.client ?? '').isNotEmpty) employee.client!,
              ].join('  ·  '),
              style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}

/// The form, and the three places it says what saving means.
class _ProposeForm extends ConsumerStatefulWidget {
  final int employeeId;
  final EditableContractModel contract;
  const _ProposeForm({required this.employeeId, required this.contract});

  @override
  ConsumerState<_ProposeForm> createState() => _ProposeFormState();
}

class _ProposeFormState extends ConsumerState<_ProposeForm> {
  late final List<EditableFieldModel> _allFields = [
    for (final g in widget.contract.sections) ...g.fields,
  ];

  late final Map<String, TextEditingController> _controllers = {
    for (final f in _allFields) f.name: TextEditingController(text: f.value ?? ''),
  };

  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Only what actually moved.
  ///
  /// Sending all ten fields would put ten rows in front of the reviewer, of
  /// which eight are identical — and the server would discard them anyway.
  Map<String, String> get _changed {
    final out = <String, String>{};

    for (final f in _allFields) {
      final typed = _controllers[f.name]?.text.trim() ?? '';
      if (typed != (f.value ?? '').trim()) out[f.name] = typed;
    }

    return out;
  }

  Future<void> _send() async {
    final changes = _changed;

    if (changes.isEmpty) {
      setState(() => _error = 'Nothing has been changed yet.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to the account manager?'),
        content: Text(
          'You are asking to change ${changes.length} '
          '${changes.length == 1 ? 'detail' : 'details'} on this person.\n\n'
          'Nothing on the record moves until they approve it, and you cannot '
          'withdraw this yourself.',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final message = await proposeEmployeeChange(ref, widget.employeeId, changes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.contract.canPropose;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Said before anything is typed, in the server's own words.
          if (widget.contract.notice.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 17, color: AppColors.warning),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      widget.contract.notice,
                      style: const TextStyle(
                          fontSize: 12, height: 1.45, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

          if (locked) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hourglass_bottom_rounded,
                      size: 17, color: AppColors.textMuted),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'A change is already waiting on this person'
                      '${widget.contract.pending?.requestedBy != null ? ', sent by ${widget.contract.pending!.requestedBy}' : ''}'
                      '. Nothing further can be sent until it is approved or declined.',
                      style: const TextStyle(
                          fontSize: 12, height: 1.45, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpace.lg),

          // Drawn in the sections the server names, the same ones the
          // web form uses. Forty boxes in one column is not a form
          // anybody finishes on a phone.
          ...widget.contract.sections.expand((section) => [
                if (section.heading.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  SectionLabel(section.heading),
                ],
                ...section.fields.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: TextField(
                        controller: _controllers[f.name],
                        enabled: !locked && !_sending,
                        keyboardType: switch (f.type) {
                          'email' => TextInputType.emailAddress,
                          'number' => TextInputType.number,
                          _ => TextInputType.text,
                        },
                        maxLines: f.type == 'textarea' ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: f.label,
                          isDense: true,
                          // A date is typed as the server stores it;
                          // saying so beats a silent rejection.
                          hintText: f.type == 'date' ? 'YYYY-MM-DD' : null,
                        ),
                      ),
                    )),
              ]),

          if (_error != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(_error!,
                style: const TextStyle(fontSize: 12, color: AppColors.error)),
            const SizedBox(height: AppSpace.sm),
          ],

          // Said again at the point of action: the banner at the top is off
          // the screen by the time somebody reaches this button.
          const Text(
            'Employment status, holds and terminations are not on this form: '
            'each needs a reason and a date recorded with it, and the account '
            'manager’s own screen does that.',
            style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpace.md),

          FilledButton.icon(
            onPressed: locked || _sending ? null : _send,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            icon: _sending
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 17),
            label: Text(_sending ? 'Sending…' : 'Send to account manager'),
          ),
        ],
      ),
    );
  }
}

class _Attendance extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _Attendance({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.fingerprint_rounded,
          title: 'No attendance recorded yet',
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg, vertical: AppSpace.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (rows[i]['date'] ?? '').toString().split('T').first,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                  Flexible(
                    child: AppChip(
                      label: _label(rows[i]['status']?.toString()),
                      tone: _tone(rows[i]['status']?.toString()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _label(String? s) => switch (s) {
        'present' => 'Present',
        'late' => 'Late',
        'absent' => 'Absent',
        'half_day' => 'Half day',
        'leave' => 'On leave',
        _ => s == null || s.isEmpty ? 'Not recorded' : s,
      };

  static Color _tone(String? s) => switch (s) {
        'present' => AppColors.success,
        'late' => AppColors.warning,
        'absent' => AppColors.error,
        'half_day' => AppColors.info,
        'leave' => AppColors.info,
        _ => AppColors.textMuted,
      };
}
