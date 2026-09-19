import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/workforce_provider.dart';
import '../../widgets/status_badge.dart';

/// Performance improvement plans.
///
/// Read-only on a phone, deliberately. A PIP is a conversation with HR and a
/// document that both sides sign; starting or editing one on a handset would put
/// a serious employment decision behind a thumb.
///
/// What the phone is genuinely good for is the thing people actually want to
/// check: what was agreed, and how long is left.
class PipsScreen extends ConsumerWidget {
  const PipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pips = ref.watch(pipsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pipsProvider),
        child: pips.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Center(child: Text('Could not load improvement plans')),
            const SizedBox(height: 14),
            Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(pipsProvider),
                child: const Text('Try again'),
              ),
            ),
          ]),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.trending_up_rounded, size: 46, color: AppColors.textMuted),
                SizedBox(height: 14),
                Center(
                  child: Text('No improvement plans',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Nothing here is good news.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ]);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: list.length,
              itemBuilder: (_, i) => _PipCard(list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _PipCard extends StatelessWidget {
  final Map<String, dynamic> pip;

  const _PipCard(this.pip);

  @override
  Widget build(BuildContext context) {
    final objectives = List<String>.from(
        (pip['objectives'] as List?)?.map((o) => o.toString()) ?? const []);
    final remaining = (pip['days_remaining'] as num?)?.toInt();
    final active = pip['status']?.toString() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pip['title']?.toString() ?? 'Improvement plan',
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    if (pip['employee_name'] != null) ...[
                      const SizedBox(height: 2),
                      Text(pip['employee_name'].toString(),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              StatusBadge(pip['status']?.toString() ?? 'draft'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '${pip['start_date'] ?? '—'} → ${pip['end_date'] ?? '—'}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          // The number people actually want. Shown only while the plan is
          // running: "0 days left" on a closed plan reads as a threat.
          if (active && remaining != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: remaining <= 7 ? AppColors.warningLight : AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                remaining == 0
                    ? 'Review is due today'
                    : '$remaining day${remaining == 1 ? '' : 's'} until review',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: remaining <= 7 ? const Color(0xFF92400E) : AppColors.info,
                ),
              ),
            ),
          ],
          if ((pip['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(pip['description'].toString(),
                style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
          ],
          if (objectives.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('WHAT WAS AGREED',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted)),
            const SizedBox(height: 8),
            ...objectives.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 6, right: 9),
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Text(o,
                            style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],
          if ((pip['outcome'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OUTCOME',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 5),
                  Text(pip['outcome'].toString(),
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
