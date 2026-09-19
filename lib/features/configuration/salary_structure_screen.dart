import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/configuration_provider.dart';

/// Salary grades and salary components on one screen, two tabs.
///
/// They belong together because they are the two halves of what a salary is made
/// of: the band a job sits in, and the allowances and deductions applied on top.
/// Somebody checking one is usually about to check the other.
///
/// Components carry a warning the grades do not. `PayrollService` recognises the
/// statutory deductions by code — `NSSF_EMP`, `NSSF_CO` — so those two are marked
/// and cannot be switched off from here at all.
class SalaryStructureScreen extends ConsumerWidget {
  const SalaryStructureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [Tab(text: 'Grades'), Tab(text: 'Components')],
              ),
            ),
            const Expanded(
              child: TabBarView(children: [_GradesTab(), _ComponentsTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

final _money = NumberFormat.decimalPattern();

// ── Grades ─────────────────────────────────────────────────────────────────

class _GradesTab extends ConsumerWidget {
  const _GradesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(salaryGradesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: grades.maybeWhen(
        data: (d) => d.canConfigure
            ? FloatingActionButton.extended(
                heroTag: 'grade',
                onPressed: () => _addGrade(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New grade'),
              )
            : null,
        orElse: () => null,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(salaryGradesProvider),
        child: grades.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _error(() => ref.invalidate(salaryGradesProvider), 'grades'),
          data: (d) => d.items.isEmpty
              ? _empty(Icons.layers_outlined, 'No salary grades',
                  'Grades set the pay band a job sits in.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: d.items.length,
                  itemBuilder: (_, i) => _gradeCard(d.items[i]),
                ),
        ),
      ),
    );
  }

  Widget _gradeCard(Map<String, dynamic> g) {
    final label = (g['label'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(g['grade']?.toString() ?? '',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The label used never to be saved, so older grades have none.
                // Showing the band instead of an empty line keeps the row useful.
                Text(label.isEmpty ? 'Unlabelled grade' : label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: label.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                      fontStyle: label.isEmpty ? FontStyle.italic : null,
                    )),
                const SizedBox(height: 3),
                Text(
                  'UGX ${_money.format(g['basic_min'] ?? 0)} – ${_money.format(g['basic_max'] ?? 0)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addGrade(BuildContext context, WidgetRef ref) async {
    final grade = TextEditingController();
    final label = TextEditingController();
    final min = TextEditingController();
    final max = TextEditingController();

    final ok = await _sheet(
      context,
      title: 'New salary grade',
      fields: [
        TextField(
          controller: grade,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              labelText: 'Grade', hintText: 'G1', border: OutlineInputBorder()),
        ),
        TextField(
          controller: label,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Label', hintText: 'Junior, Associate, Lead',
              border: OutlineInputBorder()),
        ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: min,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Minimum', prefixText: 'UGX ', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: max,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Maximum', prefixText: 'UGX ', border: OutlineInputBorder()),
            ),
          ),
        ]),
      ],
      confirmLabel: 'Create grade',
    );

    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(configurationActionsProvider.notifier).createGrade(
          grade: grade.text.trim(),
          label: label.text.trim(),
          min: num.tryParse(min.text.trim()) ?? 0,
          max: num.tryParse(max.text.trim()) ?? 0,
        );

    if (error == null) {
      ref.invalidate(salaryGradesProvider);
      messenger.showSnackBar(const SnackBar(
          content: Text('Grade created.'), backgroundColor: AppColors.success));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
  }
}

// ── Components ─────────────────────────────────────────────────────────────

class _ComponentsTab extends ConsumerWidget {
  const _ComponentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final components = ref.watch(salaryComponentsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: components.maybeWhen(
        data: (d) => d.canConfigure
            ? FloatingActionButton.extended(
                heroTag: 'component',
                onPressed: () => _addComponent(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New component'),
              )
            : null,
        orElse: () => null,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(salaryComponentsProvider),
        child: components.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _error(() => ref.invalidate(salaryComponentsProvider), 'components'),
          data: (d) => d.items.isEmpty
              ? _empty(Icons.tune_rounded, 'No salary components',
                  'Allowances and deductions applied on top of basic pay.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: d.items.length,
                  itemBuilder: (_, i) =>
                      _ComponentCard(d.items[i], canConfigure: d.canConfigure),
                ),
        ),
      ),
    );
  }

  Future<void> _addComponent(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final code = TextEditingController();
    final value = TextEditingController();
    String type = 'allowance';
    bool isFixed = true;
    bool isTaxable = false;

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
                const Text('New salary component',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Name', hintText: 'Housing Allowance',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    hintText: 'HRA',
                    // Payroll matches components by code, so it is not decoration.
                    helperText: 'Payroll identifies the component by this',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'allowance', label: Text('Allowance')),
                    ButtonSegment(value: 'deduction', label: Text('Deduction')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setSheet(() => type = s.first),
                ),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Fixed amount')),
                    ButtonSegment(value: false, label: Text('% of basic')),
                  ],
                  selected: {isFixed},
                  onSelectionChanged: (s) => setSheet(() => isFixed = s.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isFixed ? 'Amount' : 'Percentage',
                    prefixText: isFixed ? 'UGX ' : null,
                    suffixText: isFixed ? null : '%',
                    border: const OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isTaxable,
                  onChanged: (v) => setSheet(() => isTaxable = v),
                  title: const Text('Taxable', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Counts toward PAYE', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (name.text.trim().isEmpty || code.text.trim().isEmpty)
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: const Text('Create component'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final parsed = num.tryParse(value.text.trim()) ?? 0;

    final error = await ref.read(configurationActionsProvider.notifier).createComponent(
          name: name.text.trim(),
          code: code.text.trim(),
          type: type,
          isFixed: isFixed,
          isTaxable: isTaxable,
          amount: isFixed ? parsed : null,
          percentage: isFixed ? null : parsed,
        );

    if (error == null) {
      ref.invalidate(salaryComponentsProvider);
      messenger.showSnackBar(const SnackBar(
          content: Text('Component created.'), backgroundColor: AppColors.success));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
  }
}

class _ComponentCard extends ConsumerWidget {
  final Map<String, dynamic> component;
  final bool canConfigure;

  const _ComponentCard(this.component, {required this.canConfigure});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = component['is_active'] == true;
    final statutory = component['is_statutory'] == true;
    final isFixed = component['is_fixed'] == true;
    final deduction = component['type'] == 'deduction';

    final value = isFixed
        ? 'UGX ${_money.format(component['amount'] ?? 0)}'
        : '${component['percentage'] ?? 0}% of basic';

    return Opacity(
      // A switched-off component still shows, faded: it explains a payslip from
      // a month when it was on.
      opacity: active ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  deduction ? Icons.remove_circle_outline : Icons.add_circle_outline,
                  size: 18,
                  color: deduction ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(component['name']?.toString() ?? '',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(component['code']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Text(value,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (component['is_taxable'] == true) _tag('Taxable', AppColors.warningLight, AppColors.warning),
                if (statutory) _tag('Statutory', AppColors.infoLight, AppColors.info),
                if (!active) _tag('Off', AppColors.cardBorder, AppColors.textSecondary),
                const Spacer(),
                if (canConfigure && !statutory)
                  Switch(
                    value: active,
                    onChanged: (v) => _toggle(context, ref, v),
                  ),
                if (statutory)
                  const Tooltip(
                    message: 'NSSF is statutory and cannot be switched off here',
                    child: Icon(Icons.lock_outline_rounded, size: 17, color: AppColors.textMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      );

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool active) async {
    final messenger = ScaffoldMessenger.of(context);

    // Switching something off changes next month's pay for everybody who has it,
    // so it is confirmed rather than taken on a stray thumb.
    if (!active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Switch this off?'),
          content: Text(
            '${component['name']} will stop being applied on the next payroll run '
            'for everybody who has it.',
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch off'),
            ),
          ],
        ),
      );

      if (ok != true) return;
    }

    final error = await ref
        .read(configurationActionsProvider.notifier)
        .setComponentActive(component['id'] as int, active);

    if (error == null) {
      ref.invalidate(salaryComponentsProvider);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
  }
}

// ── shared bits ────────────────────────────────────────────────────────────

Widget _empty(IconData icon, String title, String body) => ListView(children: [
      const SizedBox(height: 110),
      Icon(icon, size: 46, color: AppColors.textMuted),
      const SizedBox(height: 14),
      Center(
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Text(body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
      ),
    ]);

Widget _error(VoidCallback retry, String what) => ListView(children: [
      const SizedBox(height: 110),
      const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted),
      const SizedBox(height: 14),
      Center(child: Text('Could not load $what')),
      const SizedBox(height: 14),
      Center(child: OutlinedButton(onPressed: retry, child: const Text('Try again'))),
    ]);

Future<bool?> _sheet(
  BuildContext context, {
  required String title,
  required List<Widget> fields,
  required String confirmLabel,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            for (final field in fields) ...[field, const SizedBox(height: 14)],
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
