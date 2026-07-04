import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/recruitment_provider.dart';
import '../../core/models/recruitment_model.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'open';

  String get _paramsKey {
    final parts = <String>['status=$_statusFilter'];
    if (_searchCtrl.text.isNotEmpty) parts.add('search=${_searchCtrl.text}');
    return parts.join('&');
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider(_paramsKey));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search jobs...',
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'all', child: Text('All')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'open'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateJobDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Post Job'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          jobsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (jobs) {
              if (jobs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.work_off_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No job postings found', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: jobs.map((j) => _JobCard(job: j)).toList());
            },
          ),
        ],
      ),
    );
  }

  void _showCreateJobDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _CreateJobDialog(ref: ref));
  }
}

class _JobCard extends StatelessWidget {
  final JobPostingModel job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusFg) = switch (job.status) {
      'open' => (AppColors.successLight, AppColors.success),
      'closed' => (AppColors.errorLight, AppColors.error),
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
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.work_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(job.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(width: 10),
                    if (job.referenceNumber != null)
                      Text('· ${job.referenceNumber}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (job.department != null) ...[
                      const Icon(Icons.corporate_fare_rounded, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(job.department!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                    ],
                    if (job.employmentType != null) ...[
                      const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(job.employmentType!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                    ],
                    if (job.location != null) ...[
                      const Icon(Icons.location_on_rounded, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(job.location!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
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
                child: Text(job.status[0].toUpperCase() + job.status.substring(1),
                    style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text('${job.candidatesCount} candidates',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (job.deadline != null)
                Text('Deadline: ${job.deadline}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'view') context.go('/recruitment/candidates?job=${job.id}');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.people_rounded, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('View Candidates')])),
            ],
            child: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CreateJobDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _CreateJobDialog({required this.ref});

  @override
  ConsumerState<_CreateJobDialog> createState() => _CreateJobDialogState();
}

class _CreateJobDialogState extends ConsumerState<_CreateJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _reqCtrl = TextEditingController();
  String _type = 'full_time';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Post a Job', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Job Title'), validator: (v) => v?.isEmpty == true ? 'Required' : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Location'))),
                    const SizedBox(width: 12),
                    Expanded(child: DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Employment Type'),
                      items: const [
                        DropdownMenuItem(value: 'full_time', child: Text('Full Time')),
                        DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
                        DropdownMenuItem(value: 'contract', child: Text('Contract')),
                        DropdownMenuItem(value: 'intern', child: Text('Internship')),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'full_time'),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Job Description')),
                const SizedBox(height: 12),
                TextFormField(controller: _reqCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Requirements')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Post Job'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await widget.ref.read(recruitmentActionsProvider.notifier).createJob({
      'title': _titleCtrl.text,
      'location': _locationCtrl.text,
      'employment_type': _type,
      'description': _descCtrl.text,
      'requirements': _reqCtrl.text,
    });
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job posted'), backgroundColor: AppColors.success));
        widget.ref.invalidate(jobsProvider);
      }
    }
  }
}
