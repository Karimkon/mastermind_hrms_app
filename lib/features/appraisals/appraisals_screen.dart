import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/appraisal_provider.dart';
import '../../widgets/status_badge.dart';

/// Appraisal cards, sorted by whether they are waiting on you.
///
/// The old BSC screen listed cycles and let you go looking for your own entry.
/// That is the wrong shape for a phone: the question somebody opens this app to
/// answer is "is anything waiting for me", and a list of cycles does not answer
/// it.
///
/// So the list leads with the cards where `your_move` is set. The server decides
/// that — working it out here would put a second copy of the workflow in Dart.
class AppraisalsScreen extends ConsumerWidget {
  const AppraisalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(appraisalsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(appraisalsProvider),
        child: cards.when(
          loading: () => const _LoadingList(),
          error: (e, _) => _Failed(onRetry: () => ref.invalidate(appraisalsProvider)),
          data: (list) {
            if (list.isEmpty) return const _Empty();

            final waiting = list.where((a) => a['your_move'] != null).toList();
            final rest = list.where((a) => a['your_move'] == null).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (waiting.isNotEmpty) ...[
                  _SectionHeader('Waiting for you', count: waiting.length, urgent: true),
                  const SizedBox(height: 10),
                  ...waiting.map((a) => _AppraisalCard(a, highlight: true)),
                  const SizedBox(height: 24),
                ],
                if (rest.isNotEmpty) ...[
                  _SectionHeader(waiting.isEmpty ? 'Appraisals' : 'Everything else',
                      count: rest.length),
                  const SizedBox(height: 10),
                  ...rest.map((a) => _AppraisalCard(a)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool urgent;

  const _SectionHeader(this.title, {required this.count, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: urgent ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: urgent ? AppColors.infoLight : AppColors.cardBorder,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: urgent ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppraisalCard extends StatelessWidget {
  final Map<String, dynamic> a;
  final bool highlight;

  const _AppraisalCard(this.a, {this.highlight = false});

  /// What this person is being asked to do, in words rather than a status code.
  static String _callToAction(String move) => switch (move) {
        'score' => 'Score this appraisal',
        'confirm' => 'Confirm or send back',
        'self_appraise' => 'Read and sign it off',
        _ => 'Open',
      };

  @override
  Widget build(BuildContext context) {
    final move = a['your_move'] as String?;
    final percent = (a['overall_percent'] as num?)?.toDouble();
    final unrated = (a['unrated_count'] as num?)?.toInt() ?? 0;
    final kpiCount = (a['kpi_count'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.primary.withValues(alpha: 0.35) : AppColors.cardBorder,
          width: highlight ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/appraisals/${a['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                          Text(
                            a['employee_name']?.toString() ?? 'Unnamed employee',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [a['title'], a['period'], a['year']?.toString()]
                                .where((s) => s != null && s.toString().isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(a['status']?.toString() ?? 'draft'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // A percentage is only meaningful once every KPI is rated, so
                    // an unfinished card shows its progress instead of a number
                    // that would read as a result.
                    if (percent != null && unrated == 0)
                      _Metric('${percent.toStringAsFixed(1)}%',
                          a['band_label']?.toString() ?? 'Overall')
                    else
                      _Metric('${kpiCount - unrated}/$kpiCount', 'KPIs rated'),
                    const Spacer(),
                    if (move != null)
                      Row(
                        children: [
                          Text(
                            _callToAction(move),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.primary),
                        ],
                      )
                    else
                      Text(
                        a['status_label']?.toString() ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    // Shaped like the cards it is standing in for, so the list does not jump
    // when the real data lands.
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        height: 104,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      // A ListView so pull-to-refresh still works on an empty screen.
      children: const [
        SizedBox(height: 120),
        Icon(Icons.assignment_outlined, size: 48, color: AppColors.textMuted),
        SizedBox(height: 14),
        Center(
          child: Text('No appraisals yet',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'Cards appear here once HR has set the KPIs for a review period.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  final VoidCallback onRetry;

  const _Failed({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted),
        const SizedBox(height: 14),
        const Center(
          child: Text('Could not load appraisals',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 14),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Try again'))),
      ],
    );
  }
}
