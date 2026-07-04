import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/dashboard_provider.dart';

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: dashAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
        error: (e, _) => Text('Error: $e'),
        data: (data) {
          final pendingLeaves = data['pending_leaves'] as List? ?? [];
          final pendingCandidates = data['pending_candidates'] as List? ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatCard(label: 'Leave Approvals Pending', value: '${pendingLeaves.length}', icon: Icons.event_busy_rounded, color: AppColors.warning, bg: AppColors.warningLight),
                  const SizedBox(width: 16),
                  _StatCard(label: 'Candidates to Review', value: '${pendingCandidates.length}', icon: Icons.person_search_rounded, color: AppColors.primary, bg: AppColors.infoLight),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _Card(
                    title: 'Pending Leave Requests',
                    action: TextButton(onPressed: () => context.go('/client/leaves'), child: const Text('View All', style: TextStyle(fontSize: 12))),
                    child: pendingLeaves.isEmpty
                        ? const _Empty(label: 'No pending leave requests')
                        : Column(children: pendingLeaves.take(5).map((l) => _LeaveRow(leave: l)).toList()),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _Card(
                    title: 'Candidates Awaiting Review',
                    action: TextButton(onPressed: () => context.go('/client/recruitment'), child: const Text('View All', style: TextStyle(fontSize: 12))),
                    child: pendingCandidates.isEmpty
                        ? const _Empty(label: 'No candidates pending review')
                        : Column(children: pendingCandidates.take(5).map((c) => _CandidateRow(candidate: c)).toList()),
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    ]),
  ));
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _Card({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
    child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 16), child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        if (action != null) action!,
      ])),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(16), child: child),
    ]),
  );
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
  );
}

class _LeaveRow extends StatelessWidget {
  final Map<String, dynamic> leave;
  const _LeaveRow({required this.leave});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      CircleAvatar(radius: 16, backgroundColor: AppColors.infoLight, child: Text((leave['employee'] as String? ?? '?')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(leave['employee'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text('${leave['leave_type'] ?? ''} · ${leave['days'] ?? 0} days', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
    ]),
  );
}

class _CandidateRow extends StatelessWidget {
  final Map<String, dynamic> candidate;
  const _CandidateRow({required this.candidate});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      CircleAvatar(radius: 16, backgroundColor: AppColors.infoLight, child: Text((candidate['name'] as String? ?? '?')[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(candidate['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(candidate['job_title'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Text('${candidate['score'] ?? 0}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );
}
