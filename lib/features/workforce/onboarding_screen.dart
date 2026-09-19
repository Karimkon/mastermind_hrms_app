import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/workforce_provider.dart';

/// The joining checklist.
///
/// A new starter's first week is the worst time to be told to go and find a
/// desktop, so ticking a task is one tap and unticking is the same tap again —
/// a task marked done by mistake should not cost a trip to HR.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Ids currently being written, so a row can show its own spinner instead of
  /// the whole list flickering.
  final Set<int> _saving = {};

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(onboardingProvider),
        child: list.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Center(child: Text('Could not load your checklist')),
            const SizedBox(height: 14),
            Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(onboardingProvider),
                child: const Text('Try again'),
              ),
            ),
          ]),
          data: (data) {
            if (data.tasks.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.checklist_rtl_rounded, size: 46, color: AppColors.textMuted),
                SizedBox(height: 14),
                Center(
                  child: Text('Nothing to do yet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Your joining checklist appears here once HR has set it up.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ]);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _progress(data.done, data.total),
                const SizedBox(height: 18),
                ...data.tasks.map(_tile),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _progress(int done, int total) {
    final fraction = total == 0 ? 0.0 : done / total;
    final complete = done == total && total > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(complete ? 'All done' : '$done of $total done',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (complete)
                const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(
                  complete ? AppColors.success : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> task) {
    final id = task['id'] as int;
    final done = task['completed'] == true;
    final saving = _saving.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: saving ? null : () => _toggle(id, !done),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: saving
                      ? const Padding(
                          padding: EdgeInsets.all(3),
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          done ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: done ? AppColors.success : AppColors.textMuted,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['task']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: done ? AppColors.textMuted : AppColors.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if ((task['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(task['description'].toString(),
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textSecondary, height: 1.35)),
                      ],
                      if (done && task['completed_by'] != null) ...[
                        const SizedBox(height: 4),
                        Text('Signed off by ${task['completed_by']}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(int id, bool completed) async {
    setState(() => _saving.add(id));
    final messenger = ScaffoldMessenger.of(context);

    final ok = await ref.read(workforceActionsProvider.notifier).setOnboardingTask(id, completed);

    if (!mounted) return;
    setState(() => _saving.remove(id));

    if (ok) {
      ref.invalidate(onboardingProvider);
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('That could not be saved. Please try again.'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}
