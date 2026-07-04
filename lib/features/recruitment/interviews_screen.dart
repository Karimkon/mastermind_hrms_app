import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/recruitment_provider.dart';
import '../../core/models/recruitment_model.dart';

class InterviewsScreen extends ConsumerStatefulWidget {
  const InterviewsScreen({super.key});

  @override
  ConsumerState<InterviewsScreen> createState() => _InterviewsScreenState();
}

class _InterviewsScreenState extends ConsumerState<InterviewsScreen> {
  String _statusFilter = 'all';

  String get _paramsKey {
    if (_statusFilter != 'all') return 'status=$_statusFilter';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final interviewsAsync = ref.watch(interviewsProvider(_paramsKey));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Interviews')),
                  DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showScheduleDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Schedule Interview'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          interviewsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (interviews) {
              if (interviews.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.record_voice_over_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No interviews scheduled', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: interviews.map((i) => _InterviewCard(interview: i)).toList());
            },
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _ScheduleDialog(ref: ref));
  }
}

class _InterviewCard extends StatelessWidget {
  final InterviewModel interview;
  const _InterviewCard({required this.interview});

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusFg) = switch (interview.status) {
      'completed' => (AppColors.successLight, AppColors.success),
      'cancelled' => (AppColors.errorLight, AppColors.error),
      _ => (AppColors.warningLight, AppColors.warning),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF8B5CF6), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(interview.candidate ?? 'Unknown Candidate',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(interview.job ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (interview.type.isNotEmpty) ...[
                      const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                      Text(interview.type, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                    if (interview.interviewer != null) ...[
                      const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
                      const Icon(Icons.person_rounded, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(interview.interviewer!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
                if (interview.scheduledAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(interview.scheduledAt!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                child: Text(interview.status[0].toUpperCase() + interview.status.substring(1),
                    style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              if (interview.rating != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) => Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: i < interview.rating! ? AppColors.warning : AppColors.cardBorder,
                  )),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _ScheduleDialog({required this.ref});

  @override
  ConsumerState<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<_ScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _candidateCtrl = TextEditingController();
  final _interviewerCtrl = TextEditingController();
  String _type = 'phone';
  DateTime? _scheduledAt;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule Interview', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _candidateCtrl, decoration: const InputDecoration(labelText: 'Candidate ID'), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Interview Type'),
                items: const [
                  DropdownMenuItem(value: 'phone', child: Text('Phone')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'in_person', child: Text('In Person')),
                  DropdownMenuItem(value: 'technical', child: Text('Technical')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _interviewerCtrl, decoration: const InputDecoration(labelText: 'Interviewer')),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setState(() => _scheduledAt = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Scheduled Date'),
                  child: Text(_scheduledAt != null ? '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')}' : 'Select date'),
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
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Schedule'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await widget.ref.read(recruitmentActionsProvider.notifier).scheduleInterview({
      'candidate_id': int.tryParse(_candidateCtrl.text),
      'type': _type,
      'interviewer': _interviewerCtrl.text,
      if (_scheduledAt != null) 'scheduled_at': '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')}',
    });
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interview scheduled'), backgroundColor: AppColors.success));
        widget.ref.invalidate(interviewsProvider);
      }
    }
  }
}
