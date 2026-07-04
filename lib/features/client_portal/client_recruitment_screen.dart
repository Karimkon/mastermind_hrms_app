import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';

final _clientRecruitmentProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.clientRecruitment);
    final body = res.data as Map<String, dynamic>;
    final rawList = body['data'];
    final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

class ClientRecruitmentScreen extends ConsumerWidget {
  const ClientRecruitmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(_clientRecruitmentProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Candidate Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Review shortlisted candidates for your open positions',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                        Text('No candidates pending your review', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: candidates.map((c) => _CandidateReviewCard(candidate: c, ref: ref)).toList());
            },
          ),
        ],
      ),
    );
  }
}

class _CandidateReviewCard extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final WidgetRef ref;
  const _CandidateReviewCard({required this.candidate, required this.ref});

  @override
  Widget build(BuildContext context) {
    final score = (candidate['score'] as num?)?.toInt() ?? 0;
    final scoreColor = score >= 80 ? AppColors.success : score >= 60 ? AppColors.warning : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.infoLight,
            child: Text(
              (candidate['name'] as String? ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(candidate['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                if (candidate['job_title'] != null)
                  Row(
                    children: [
                      const Icon(Icons.work_rounded, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(candidate['job_title'] as String, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // AI Score
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withOpacity(0.1),
                  border: Border.all(color: scoreColor, width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$score', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: scoreColor)),
                      Text('AI', style: TextStyle(fontSize: 9, color: scoreColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await ApiService.post('${ApiConstants.clientRecruitment}/${candidate['id']}/approve');
                  ref.invalidate(_clientRecruitmentProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate approved'), backgroundColor: AppColors.success));
                },
                icon: const Icon(Icons.thumb_up_rounded, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.description_rounded, size: 16, color: AppColors.primary),
                label: const Text('View Resume', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
