import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/recruitment_provider.dart';
import '../../core/models/recruitment_model.dart';

class CandidatesScreen extends ConsumerStatefulWidget {
  const CandidatesScreen({super.key});

  @override
  ConsumerState<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends ConsumerState<CandidatesScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';

  String get _paramsKey {
    final parts = <String>[];
    if (_statusFilter != 'all') parts.add('status=$_statusFilter');
    if (_searchCtrl.text.isNotEmpty) parts.add('search=${_searchCtrl.text}');
    return parts.join('&');
  }

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(candidatesProvider(_paramsKey));

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
                    hintText: 'Search candidates...',
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(value: 'screening', child: Text('Screening')),
                  DropdownMenuItem(value: 'shortlisted', child: Text('Shortlisted')),
                  DropdownMenuItem(value: 'interview', child: Text('Interview')),
                  DropdownMenuItem(value: 'offer', child: Text('Offer')),
                  DropdownMenuItem(value: 'hired', child: Text('Hired')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          candidatesAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (candidates) {
              if (candidates.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.person_search_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No candidates found', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return _CandidatesTable(candidates: candidates, ref: ref);
            },
          ),
        ],
      ),
    );
  }
}

class _CandidatesTable extends StatelessWidget {
  final List<CandidateModel> candidates;
  final WidgetRef ref;
  const _CandidatesTable({required this.candidates, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _ColHead('Candidate')),
                Expanded(flex: 2, child: _ColHead('Applied For')),
                Expanded(child: _ColHead('Score')),
                Expanded(child: _ColHead('Status')),
                Expanded(child: _ColHead('Actions')),
              ],
            ),
          ),
          const Divider(height: 1),
          ...candidates.map((c) => _CandidateRow(candidate: c, ref: ref)),
        ],
      ),
    );
  }
}

class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary));
  }
}

class _CandidateRow extends StatelessWidget {
  final CandidateModel candidate;
  final WidgetRef ref;
  const _CandidateRow({required this.candidate, required this.ref});

  @override
  Widget build(BuildContext context) {
    final score = candidate.score;
    final scoreColor = score >= 80 ? AppColors.success : score >= 60 ? AppColors.warning : AppColors.error;

    final (statusBg, statusFg) = switch (candidate.status) {
      'hired' => (AppColors.successLight, AppColors.success),
      'rejected' => (AppColors.errorLight, AppColors.error),
      'offer' || 'shortlisted' => (AppColors.infoLight, AppColors.info),
      'screening' || 'interview' => (const Color(0xFFF5F3FF), const Color(0xFF8B5CF6)),
      _ => (AppColors.warningLight, AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.infoLight,
                child: Text(candidate.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(candidate.email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              )),
            ],
          )),
          Expanded(flex: 2, child: Text(candidate.jobTitle ?? '-', style: const TextStyle(fontSize: 13))),
          Expanded(child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: scoreColor.withOpacity(0.1)),
                child: Center(child: Text('$score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: scoreColor))),
              ),
            ],
          )),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
            child: Text(candidate.status[0].toUpperCase() + candidate.status.substring(1),
                style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.w600)),
          )),
          Expanded(child: PopupMenuButton<String>(
            onSelected: (action) async {
              if (action != 'view') {
                await ref.read(recruitmentActionsProvider.notifier).updateCandidateStatus(candidate.id, action);
                ref.invalidate(candidatesProvider);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'view', child: Text('View Profile')),
              PopupMenuItem(value: 'screening', child: Text('Mark Screening')),
              PopupMenuItem(value: 'shortlisted', child: Text('Shortlist')),
              PopupMenuItem(value: 'interview', child: Text('Schedule Interview')),
              PopupMenuItem(value: 'offer', child: Text('Send Offer')),
              PopupMenuItem(value: 'hired', child: Text('Mark Hired')),
              PopupMenuItem(value: 'rejected', child: Text('Reject')),
            ],
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Actions', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.primary),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
