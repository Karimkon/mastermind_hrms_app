import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/probation_model.dart';
import '../../core/providers/probation_provider.dart';

class ProbationScreen extends ConsumerStatefulWidget {
  const ProbationScreen({super.key});

  @override
  ConsumerState<ProbationScreen> createState() => _ProbationScreenState();
}

class _ProbationScreenState extends ConsumerState<ProbationScreen> {
  String? _statusFilter;

  static const _tabs = [
    (label: 'All',        value: null),
    (label: 'Active',     value: 'on_probation'),
    (label: 'Passed',     value: 'passed'),
    (label: 'Overdue',    value: 'overdue'),
  ];

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(probationListProvider(_statusFilter));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(probationListProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(probationListProvider),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            _StatsRow(stats: data.stats),
            const SizedBox(height: 20),
            _FilterTabs(
              tabs:     _tabs,
              selected: _statusFilter,
              onSelect: (v) => setState(() => _statusFilter = v),
            ),
            const SizedBox(height: 16),
            if (data.employees.isEmpty)
              const _EmptyState()
            else
              ...data.employees.map((e) => _EmployeeCard(
                    employee: e,
                    onSetEnd:  () => _showSetEndDialog(context, e),
                    onConfirm: () => _showConfirmDialog(context, e),
                  )),
          ]),
        ),
      ),
    );
  }

  void _showSetEndDialog(BuildContext context, ProbationEmployeeModel emp) {
    DateTime? picked = emp.probationEndDate != null ? DateTime.tryParse(emp.probationEndDate!) : null;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Set Probation End — ${emp.fullName}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (picked != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Selected: ${DateFormat('d MMM y').format(picked!)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: picked ?? DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (d != null) setDState(() => picked = d);
              },
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Pick Date'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: picked == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        final msg = await ref.read(probationActionsProvider.notifier)
                            .setEnd(emp.id, DateFormat('yyyy-MM-dd').format(picked!));
                        if (mounted) _showSnack(msg);
                      } catch (e) {
                        if (mounted) _showSnack('$e', isError: true);
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, ProbationEmployeeModel emp) {
    String outcome = 'passed';
    final notesCtrl = TextEditingController();
    String? newEndDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Confirm Probation — ${emp.fullName}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Outcome:', style: TextStyle(fontWeight: FontWeight.w600)),
              RadioListTile(title: const Text('Passed'), value: 'passed', groupValue: outcome, onChanged: (v) => setDState(() => outcome = v!), dense: true),
              RadioListTile(title: const Text('Failed'), value: 'failed', groupValue: outcome, onChanged: (v) => setDState(() => outcome = v!), dense: true),
              RadioListTile(title: const Text('Extended'), value: 'extended', groupValue: outcome, onChanged: (v) => setDState(() => outcome = v!), dense: true),
              const SizedBox(height: 12),
              if (outcome == 'extended')
                ElevatedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) setDState(() => newEndDate = DateFormat('yyyy-MM-dd').format(d));
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(newEndDate ?? 'Pick New End Date'),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: outcome == 'passed' ? AppColors.success : outcome == 'failed' ? AppColors.error : AppColors.warning,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final msg = await ref.read(probationActionsProvider.notifier).confirm(
                    emp.id, outcome,
                    notes:      notesCtrl.text.isEmpty ? null : notesCtrl.text,
                    newEndDate: outcome == 'extended' ? newEndDate : null,
                  );
                  if (mounted) _showSnack(msg);
                } catch (e) {
                  if (mounted) _showSnack('$e', isError: true);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final ProbationStatsModel stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _StatCard(label: 'On Probation', value: stats.onProbation, color: AppColors.primary)),
    const SizedBox(width: 10),
    Expanded(child: _StatCard(label: 'Passed', value: stats.passed, color: AppColors.success)),
    const SizedBox(width: 10),
    Expanded(child: _StatCard(label: 'Due This Month', value: stats.dueThisMonth, color: AppColors.warning)),
    const SizedBox(width: 10),
    Expanded(child: _StatCard(label: 'Overdue', value: stats.overdue, color: AppColors.error)),
  ]);
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.3))),
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Column(children: [
      Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 2),
    ])),
  );
}

class _FilterTabs extends StatelessWidget {
  final List<({String label, String? value})> tabs;
  final String? selected;
  final void Function(String?) onSelect;

  const _FilterTabs({required this.tabs, this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: tabs.map((t) {
      final isActive = selected == t.value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => onSelect(t.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isActive ? AppColors.primary : AppColors.cardBorder),
            ),
            child: Text(t.label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400, color: isActive ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
    }).toList()),
  );
}

class _EmployeeCard extends StatelessWidget {
  final ProbationEmployeeModel employee;
  final VoidCallback onSetEnd;
  final VoidCallback onConfirm;

  const _EmployeeCard({required this.employee, required this.onSetEnd, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final initials = employee.fullName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    final isOverdue = employee.isOverdue;

    Color statusColor = AppColors.textMuted;
    Color statusBg = const Color(0xFFF1F5F9);

    if (employee.probationStatus == 'on_probation') {
      statusColor = isOverdue ? AppColors.error : AppColors.warning;
      statusBg    = isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);
    } else if (employee.probationStatus == 'passed') {
      statusColor = AppColors.success;
      statusBg    = const Color(0xFFECFDF5);
    } else if (employee.probationStatus == 'failed') {
      statusColor = AppColors.error;
      statusBg    = const Color(0xFFFEF2F2);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isOverdue ? AppColors.error.withOpacity(0.5) : AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 20, backgroundColor: AppColors.primary, child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employee.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${employee.empNumber} · ${employee.designation ?? ''} · ${employee.department ?? ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
              child: Text(employee.statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text('Hired: ${employee.hireDate ?? '--'}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            if (employee.probationEndDate != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.timer_rounded, size: 12, color: isOverdue ? AppColors.error : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'End: ${employee.probationEndDate}${isOverdue ? ' (OVERDUE)' : employee.daysLeft != null ? ' (${employee.daysLeft}d left)' : ''}',
                style: TextStyle(fontSize: 11, color: isOverdue ? AppColors.error : AppColors.textSecondary),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton.icon(
              onPressed: onSetEnd,
              icon: const Icon(Icons.edit_calendar_rounded, size: 14),
              label: const Text('Set End Date', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
            const SizedBox(width: 8),
            if (employee.probationStatus == 'on_probation' || employee.probationStatus == null)
              ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_rounded, size: 14),
                label: const Text('Confirm Outcome', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(children: [
      SizedBox(height: 40),
      Icon(Icons.person_search_rounded, size: 48, color: AppColors.textMuted),
      SizedBox(height: 12),
      Text('No probation records found.', style: TextStyle(color: AppColors.textMuted)),
    ]),
  );
}
