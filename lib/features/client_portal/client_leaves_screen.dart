import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';

final _clientLeavesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.clientLeaves);
    final body = res.data as Map<String, dynamic>;
    final rawList = body['data'];
    final List list = rawList is List ? rawList : (rawList is Map ? rawList['data'] ?? [] : []);
    return list.map((j) => j as Map<String, dynamic>).toList();
  } catch (_) {
    return [];
  }
});

class ClientLeavesScreen extends ConsumerWidget {
  const ClientLeavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(_clientLeavesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Leave Approvals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Review and approve/reject leave requests from employees assigned to your organization',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          leavesAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (leaves) {
              if (leaves.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.task_alt_rounded, size: 48, color: AppColors.success),
                        SizedBox(height: 12),
                        Text('All caught up! No pending approvals.', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: leaves.map((l) => _LeaveApprovalCard(leave: l, ref: ref)).toList());
            },
          ),
        ],
      ),
    );
  }
}

class _LeaveApprovalCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final WidgetRef ref;
  const _LeaveApprovalCard({required this.leave, required this.ref});

  @override
  Widget build(BuildContext context) {
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
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.infoLight,
            child: Text(
              (leave['employee'] as String? ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leave['employee'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(10)),
                      child: Text(leave['leave_type'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text('${leave['days'] ?? 0} days', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Text('${leave['start_date'] ?? leave['from_date'] ?? ''} → ${leave['end_date'] ?? leave['to_date'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                if (leave['reason'] != null) ...[
                  const SizedBox(height: 4),
                  Text(leave['reason'], style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await ApiService.post('${ApiConstants.clientLeaves}/${leave['id']}/approve');
                  ref.invalidate(_clientLeavesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave approved'), backgroundColor: AppColors.success));
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await ApiService.post('${ApiConstants.clientLeaves}/${leave['id']}/reject');
                  ref.invalidate(_clientLeavesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave rejected'), backgroundColor: AppColors.error));
                },
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                label: const Text('Reject', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
