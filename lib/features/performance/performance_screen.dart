import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/performance_provider.dart';

class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final kpisAsync = ref.watch(kpisProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Goals & KPIs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddGoalDialog(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Goal'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Goals
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MY GOALS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    goalsAsync.when(
                      loading: () => Shimmer.fromColors(
                        baseColor: const Color(0xFFE2E8F0),
                        highlightColor: const Color(0xFFF8FAFC),
                        child: Column(children: List.generate(3, (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                        ))),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(e.toString().replaceFirst('Exception: ', ''), style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                      data: (goals) => goals.isEmpty
                          ? const _Empty(icon: Icons.flag_rounded, label: 'No goals set yet')
                          : Column(children: goals.map((g) => _GoalCard(goal: g, ref: ref)).toList()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // KPIs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MY KPIs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    kpisAsync.when(
                      loading: () => Shimmer.fromColors(
                        baseColor: const Color(0xFFE2E8F0),
                        highlightColor: const Color(0xFFF8FAFC),
                        child: Column(children: List.generate(3, (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                        ))),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(e.toString().replaceFirst('Exception: ', ''), style: const TextStyle(color: AppColors.textSecondary)),
                      ),
                      data: (kpis) => kpis.isEmpty
                          ? const _Empty(icon: Icons.bar_chart_rounded, label: 'No KPIs assigned yet')
                          : Column(children: kpis.map((k) => _KpiCard(kpi: k)).toList()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _AddGoalDialog(ref: ref));
  }
}

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final WidgetRef ref;
  const _GoalCard({required this.goal, required this.ref});

  @override
  Widget build(BuildContext context) {
    final progress = (goal['progress'] as num?)?.toInt() ?? 0;
    final status = goal['status'] as String? ?? 'in_progress';

    final (statusBg, statusFg) = switch (status) {
      'completed' => (AppColors.successLight, AppColors.success),
      'at_risk' => (AppColors.errorLight, AppColors.error),
      _ => (AppColors.infoLight, AppColors.info),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(goal['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                child: Text(status.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                    style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (goal['description'] != null) ...[
            const SizedBox(height: 6),
            Text(goal['description'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.surface,
                    color: progress >= 80 ? AppColors.success : progress >= 50 ? AppColors.warning : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$progress%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          if (goal['due_date'] != null) ...[
            const SizedBox(height: 6),
            Text('Due: ${goal['due_date']}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final Map<String, dynamic> kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final target = (kpi['target'] as num?)?.toDouble() ?? 0;
    final actual = (kpi['actual'] as num?)?.toDouble() ?? 0;
    final score = (kpi['score'] as num?)?.toInt() ?? 0;
    final pct = target > 0 ? (actual / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kpi['name'] ?? kpi['kpi_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Target: $target', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Text('Actual: $actual', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppColors.surface,
                    color: pct >= 0.8 ? AppColors.success : pct >= 0.5 ? AppColors.warning : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Text('Score', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('$score', style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: score >= 80 ? AppColors.success : score >= 50 ? AppColors.warning : AppColors.error,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Empty({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _AddGoalDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AddGoalDialog({required this.ref});

  @override
  ConsumerState<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends ConsumerState<_AddGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Goal', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Goal Title'), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setState(() => _dueDate = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due Date'),
                  child: Text(_dueDate != null ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}' : 'Select date'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Goal'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await widget.ref.read(goalActionsProvider.notifier).createGoal({
      'title': _titleCtrl.text,
      'description': _descCtrl.text,
      if (_dueDate != null) 'due_date': '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
    });
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal added'), backgroundColor: AppColors.success));
        widget.ref.invalidate(goalsProvider);
      }
    }
  }
}
