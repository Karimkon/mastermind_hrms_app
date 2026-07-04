import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/bsc_model.dart';
import '../../core/providers/bsc_provider.dart';

class BscScreen extends ConsumerWidget {
  const BscScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(bscCyclesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: 'Cycles'),
                Tab(text: 'Team Appraisals'),
              ],
            ),
          ),
          Expanded(child: TabBarView(children: [
            // ─── Cycles Tab ───────────────────────────────────────
            cyclesAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                ),
              ),
              error:   (e, _) => Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text(e.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              )),
              data:    (cycles) => cycles.isEmpty
                  ? const Center(child: Text('No BSC cycles created yet.', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: cycles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _CycleCard(cycle: cycles[i]),
                    ),
            ),
            // ─── Team Tab ─────────────────────────────────────────
            const _TeamAppraisalTab(),
          ])),
        ]),
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final BscCycleModel cycle;
  const _CycleCard({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final statusColor = cycle.isActive
        ? AppColors.success
        : cycle.isClosed
            ? AppColors.textMuted
            : AppColors.warning;

    final statusBg = cycle.isActive
        ? const Color(0xFFECFDF5)
        : cycle.isClosed
            ? const Color(0xFFF1F5F9)
            : const Color(0xFFFFF7ED);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cycle.isActive ? const Color(0xFF86EFAC) : AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('${cycle.year}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: statusColor))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cycle.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('${cycle.period}  ·  ${cycle.krasCount ?? 0} KRAs', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (cycle.startDate != null)
              Text('${cycle.startDate} → ${cycle.endDate}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
            child: Text(cycle.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
          ),
        ]),
      ),
    );
  }
}

class _TeamAppraisalTab extends ConsumerWidget {
  const _TeamAppraisalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(bscTeamAppraisalProvider);

    return teamAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data:    (data) {
        if (data.cycle == null) {
          return const Center(child: Text('No active BSC cycle.', style: TextStyle(color: AppColors.textMuted)));
        }
        if (data.team.isEmpty) {
          return const Center(child: Text('No team members found.', style: TextStyle(color: AppColors.textMuted)));
        }

        return ListView(padding: const EdgeInsets.all(20), children: [
          _CycleSummaryBanner(cycle: data.cycle!),
          const SizedBox(height: 16),
          ...data.team.map((m) => _TeamMemberCard(member: m)),
        ]);
      },
    );
  }
}

class _CycleSummaryBanner extends StatelessWidget {
  final BscCycleModel cycle;
  const _CycleSummaryBanner({required this.cycle});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.infoLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cycle.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
        Text('${cycle.period} · Active cycle', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ])),
    ]),
  );
}

class _TeamMemberCard extends ConsumerWidget {
  final BscTeamMember member;
  const _TeamMemberCard({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = member.fullName.split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.cardBorder)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 20, backgroundColor: AppColors.primary, child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${member.designation ?? ''} · ${member.department ?? ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(member.overallScore.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const Text('score', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ]),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: member.progress / 100,
              backgroundColor: AppColors.cardBorder,
              color: member.progress == 100 ? AppColors.success : AppColors.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _StatChip(label: '${member.entryCount}/${member.totalKras}', sublabel: 'KRAs', color: AppColors.primary),
            const SizedBox(width: 8),
            _StatChip(label: '${member.approvedCount}', sublabel: 'Approved', color: AppColors.success),
            const SizedBox(width: 8),
            _StatChip(label: '${member.submittedCount}', sublabel: 'Pending', color: AppColors.warning),
            const Spacer(),
            TextButton(
              onPressed: () => _showApproveDialog(context, ref, member),
              child: const Text('Review', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showApproveDialog(BuildContext context, WidgetRef ref, BscTeamMember member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeamMemberReviewSheet(member: member),
    );
  }
}

class _TeamMemberReviewSheet extends StatelessWidget {
  final BscTeamMember member;
  const _TeamMemberReviewSheet({required this.member});

  @override
  Widget build(BuildContext context) {
    final pct = (member.overallScore / 5.0).clamp(0.0, 1.0);
    final initials = member.fullName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: AppColors.primary, child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${member.designation ?? ''} · ${member.department ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(member.overallScore.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const Text('/ 5.00', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: const Color(0xFFE8F0FE),
                    color: pct == 1.0 ? AppColors.success : AppColors.primary,
                    minHeight: 8,
                  ),
                )),
                const SizedBox(width: 10),
                Text('${member.progress}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _StatChip(label: '${member.entryCount}/${member.totalKras}', sublabel: 'KRAs Done', color: AppColors.primary),
                const SizedBox(width: 8),
                _StatChip(label: '${member.approvedCount}', sublabel: 'Approved', color: AppColors.success),
                const SizedBox(width: 8),
                _StatChip(label: '${member.submittedCount}', sublabel: 'Pending', color: AppColors.warning),
                const SizedBox(width: 8),
                _StatChip(label: '${member.totalKras - member.entryCount}', sublabel: 'Not Started', color: AppColors.textMuted),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const Text('Score Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _ScoreRow(label: 'Overall Score', value: member.overallScore.toStringAsFixed(2), highlight: true),
                _ScoreRow(label: 'Completion', value: '${member.progress}%'),
                _ScoreRow(label: 'KRAs Approved', value: '${member.approvedCount} of ${member.totalKras}'),
                _ScoreRow(label: 'Pending Review', value: '${member.submittedCount}'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _ScoreRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: highlight ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: highlight ? FontWeight.w600 : FontWeight.w400))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: highlight ? AppColors.primary : AppColors.textPrimary)),
    ]),
  );
}

class _StatChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  const _StatChip({required this.label, required this.sublabel, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Column(children: [
      Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
      Text(sublabel, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
    ]),
  );
}
