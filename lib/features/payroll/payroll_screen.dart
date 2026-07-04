import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/payroll_provider.dart';

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(payrollRunsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Payroll Runs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showNewRunDialog(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Payroll Run'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          runsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (runs) {
              if (runs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.payments_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No payroll runs yet', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: runs.map((r) => _PayrollRunCard(run: r, ref: ref)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNewRunDialog(BuildContext context, WidgetRef ref) {
    int selectedMonth = DateTime.now().month;
    int selectedYear  = DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create Payroll Run'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                items: List.generate(12, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(DateFormat('MMMM').format(DateTime(0, i + 1))),
                )),
                onChanged: (v) => setState(() => selectedMonth = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                items: List.generate(6, (i) {
                  final y = DateTime.now().year - 2 + i;
                  return DropdownMenuItem(value: y, child: Text('$y'));
                }),
                onChanged: (v) => setState(() => selectedYear = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ref.read(payrollActionsProvider.notifier).createRun(selectedMonth, selectedYear);
                if (ok) {
                  ref.invalidate(payrollRunsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Payroll run created'), backgroundColor: AppColors.success));
                  }
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed — run may already exist'), backgroundColor: AppColors.error));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayrollRunCard extends StatelessWidget {
  final Map<String, dynamic> run;
  final WidgetRef ref;
  const _PayrollRunCard({required this.run, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = run['status'] as String? ?? 'draft';
    final fmt = NumberFormat('#,##0', 'en');
    final totalGross = (run['total_gross'] as num?)?.toDouble() ?? 0;
    final totalNet   = (run['total_net']   as num?)?.toDouble() ?? 0;

    final (statusBg, statusFg) = switch (status) {
      'approved' || 'paid' => (AppColors.successLight, AppColors.success),
      'processed'          => (AppColors.infoLight, AppColors.info),
      'pending' || 'draft' => (AppColors.warningLight, AppColors.warning),
      _                    => (AppColors.surface, AppColors.textSecondary),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(run['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('${run['employee_count'] ?? 0} employees',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(color: statusFg, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                _PayStat('Gross Payroll', 'UGX ${fmt.format(totalGross)}', AppColors.primary),
                const SizedBox(width: 32),
                _PayStat('Total Deductions', 'UGX ${fmt.format(totalGross - totalNet)}', AppColors.error),
                const SizedBox(width: 32),
                _PayStat('Net Payroll', 'UGX ${fmt.format(totalNet)}', AppColors.success),
                const Spacer(),
                if (status == 'draft')
                  ElevatedButton(
                    onPressed: () async {
                      final ok = await ref.read(payrollActionsProvider.notifier).processPayroll(run['id'] as int);
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Payroll processed'), backgroundColor: AppColors.success));
                        ref.invalidate(payrollRunsProvider);
                      }
                    },
                    child: const Text('Process'),
                  ),
                if (status == 'processed') ...[
                  OutlinedButton(
                    onPressed: () => _showPayslips(context, run['id'] as int),
                    child: const Text('View Payslips'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final ok = await ref.read(payrollActionsProvider.notifier).approvePayroll(run['id'] as int);
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Payroll approved'), backgroundColor: AppColors.success));
                        ref.invalidate(payrollRunsProvider);
                      }
                    },
                    child: const Text('Approve'),
                  ),
                ],
                if (status == 'approved') ...[
                  OutlinedButton(
                    onPressed: () => _showPayslips(context, run['id'] as int),
                    child: const Text('View Payslips'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showExportInfo(context, run),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPayslips(BuildContext context, int runId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _PayslipsSheet(runId: runId),
    );
  }

  void _showExportInfo(BuildContext context, Map<String, dynamic> run) {
    final fmt = NumberFormat('#,##0', 'en');
    final gross = (run['total_gross'] as num?)?.toDouble() ?? 0;
    final net   = (run['total_net']   as num?)?.toDouble() ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.download_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Payroll Export'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(run['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            _ExportRow('Employees', '${run['employee_count'] ?? 0}'),
            _ExportRow('Gross Payroll', 'UGX ${fmt.format(gross)}'),
            _ExportRow('Net Payroll', 'UGX ${fmt.format(net)}'),
            _ExportRow('Deductions', 'UGX ${fmt.format(gross - net)}'),
            const SizedBox(height: 16),
            const Text('Download the bank payment export from the web portal:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            SelectableText(
              'https://mastermind.autos/payroll/${run['id']}/bank-export',
              style: const TextStyle(fontSize: 11, color: AppColors.primary, decoration: TextDecoration.underline),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}

class _PayslipsSheet extends ConsumerWidget {
  final int runId;
  const _PayslipsSheet({required this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipsAsync = ref.watch(runPayslipsProvider(runId));
    final fmt = NumberFormat('#,##0', 'en');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('Payslips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: payslipsAsync.when(
              loading: () => Shimmer.fromColors(
                baseColor: const Color(0xFFE2E8F0),
                highlightColor: const Color(0xFFF8FAFC),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, __) => Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                ),
              ),
              error: (e, _) => Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(e.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              )),
              data: (payslips) {
                if (payslips.isEmpty) {
                  return const Center(
                    child: Text('No payslips generated yet', style: TextStyle(color: AppColors.textMuted)));
                }
                return ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: payslips.length,
                  itemBuilder: (_, i) {
                    final p = payslips[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.infoLight,
                        child: Text(
                          (p['employee'] as String? ?? 'E').substring(0, 1),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(p['employee'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Gross: UGX ${fmt.format((p['gross_pay'] as num?)?.toDouble() ?? 0)}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                        'UGX ${fmt.format((p['net_pay'] as num?)?.toDouble() ?? 0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 13),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportRow extends StatelessWidget {
  final String label;
  final String value;
  const _ExportRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PayStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PayStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
