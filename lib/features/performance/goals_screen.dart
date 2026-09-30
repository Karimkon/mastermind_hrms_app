import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/goal_model.dart';
import '../../core/providers/goals_provider.dart';

/// The goals set for you, and how far along each one is.
///
/// Progress is the thing people come here to move, so it is a slider on the
/// card rather than something behind an edit screen.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewGoalSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New goal'),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(goalsProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(goalsProvider),
          child: data.goals.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _SummaryCard(summary: data.summary),
                    const SizedBox(height: 16),
                    ...data.goals.map((g) => _GoalCard(goal: g)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final GoalSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Overall progress',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text('${summary.progress}%',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.1)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.progress / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _Stat(label: 'Goals', value: '${summary.total}'),
            _Stat(label: 'In progress', value: '${summary.inProgress}'),
            _Stat(label: 'Achieved', value: '${summary.achieved}'),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      );
}

class _GoalCard extends ConsumerStatefulWidget {
  final GoalModel goal;
  const _GoalCard({required this.goal});

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  late double _progress = widget.goal.progress.toDouble();
  bool _saving = false;

  Color get _statusColour => switch (widget.goal.status) {
        'achieved' => const Color(0xFF16A34A),
        'missed' => const Color(0xFFDC2626),
        'in_progress' => const Color(0xFF2563EB),
        _ => const Color(0xFF64748B),
      };

  Future<void> _save() async {
    final wanted = _progress.round();
    if (wanted == widget.goal.progress) return;

    setState(() => _saving = true);
    try {
      await ref.read(goalActionsProvider).setProgress(widget.goal.id, wanted);
    } catch (e) {
      if (!mounted) return;
      // Put the bar back where it was — the server did not take the change.
      setState(() => _progress = widget.goal.progress.toDouble());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g.isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(g.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(g.statusLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColour)),
          ),
        ]),

        if (g.description != null && g.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(g.description!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
        ],

        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 4, children: [
          if (g.cycle != null) _Meta(icon: Icons.event_repeat_rounded, text: g.cycle!),
          if (g.targetDate != null)
            _Meta(
              icon: Icons.flag_rounded,
              text: g.isOverdue ? 'Due ${g.targetDate} — overdue' : 'Due ${g.targetDate}',
              tone: g.isOverdue ? const Color(0xFFDC2626) : null,
            ),
          if (g.weight > 0) _Meta(icon: Icons.scale_rounded, text: '${g.weight.toStringAsFixed(0)}% weight'),
          if (g.attachments > 0)
            _Meta(icon: Icons.attach_file_rounded, text: '${g.attachments} file(s)'),
        ]),

        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Slider(
              value: _progress,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_progress.round()}%',
              onChanged: _saving ? null : (v) => setState(() => _progress = v),
              onChangeEnd: (_) => _save(),
            ),
          ),
          SizedBox(
            width: 46,
            child: _saving
                ? const Center(
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                : Text('${_progress.round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? tone;
  const _Meta({required this.icon, required this.text, this.tone});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: tone ?? AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11.5, color: tone ?? AppColors.textMuted)),
      ]);
}

// ── New goal ────────────────────────────────────────────────────────────────

void _openNewGoalSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _NewGoalSheet(),
  );
}

class _NewGoalSheet extends ConsumerStatefulWidget {
  const _NewGoalSheet();

  @override
  ConsumerState<_NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends ConsumerState<_NewGoalSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _target;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(goalActionsProvider).create(
            title: _title.text.trim(),
            description: _description.text.trim(),
            targetDate: _target?.toIso8601String().split('T').first,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal added.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('New goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What is the goal?', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Give the goal a title.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'How will it be measured? (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _target ?? now.add(const Duration(days: 30)),
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now.add(const Duration(days: 365 * 3)),
              );
              if (picked != null) setState(() => _target = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Target date', border: OutlineInputBorder()),
              child: Text(
                _target == null
                    ? 'Not set'
                    : _target!.toIso8601String().split('T').first,
                style: TextStyle(color: _target == null ? AppColors.textMuted : null),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add goal'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── States ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(32),
        children: const [
          SizedBox(height: 60),
          Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('No goals yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          SizedBox(height: 6),
          Text(
            'Goals set for you by HR or your manager appear here. You can add your own too.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}
