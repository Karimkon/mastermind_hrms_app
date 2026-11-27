import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/supervisor_model.dart';
import '../../core/providers/supervisor_provider.dart';
import '../../core/widgets/ui.dart';

/// What the site was paid.
///
/// The web has had this screen since the supervisor module was built — behind
/// the same supervision.payroll permission, which all thirteen supervisors
/// hold — and the app had nothing of it. A supervisor stands at a client's
/// gate, where a phone is the only computer there is, and being asked what
/// somebody was paid meant going to find a laptop.
///
/// Everything here is this site's own: the server counts and totals by the
/// supervisor's current postings, because a run can span several clients and
/// another site's wage bill is none of their business. Nothing on this screen
/// filters anything — if it is on the page, the server decided it belongs there.
class SupervisorPayrollScreen extends ConsumerWidget {
  const SupervisorPayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supervisorPayrollProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Site payroll')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(supervisorPayrollProvider),
        child: async.when(
          loading: () => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpace.md),
                child: SkeletonBox(height: 88, radius: AppRadius.lg),
              ),
            ),
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: [
              EmptyState(
                icon: e is NoPostingException
                    ? Icons.location_off_rounded
                    : Icons.cloud_off_rounded,
                title: e is NoPostingException
                    ? 'You have no current posting'
                    : 'Could not load the payroll',
                detail: e.toString().replaceFirst('Exception: ', ''),
                action: e is NoPostingException
                    ? null
                    : FilledButton(
                        onPressed: () => ref.invalidate(supervisorPayrollProvider),
                        child: const Text('Try again'),
                      ),
              ),
            ],
          ),
          data: (runs) => runs.isEmpty
              ? ListView(
                  padding: EdgeInsets.all(AppSpace.page(context)),
                  children: const [
                    EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No payroll yet for your site',
                      detail: 'A run appears here once it has been processed. '
                          'A draft is still somebody\'s working copy, so the '
                          'figures in it are not real yet.',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: EdgeInsets.all(AppSpace.page(context)),
                  itemCount: runs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                  itemBuilder: (_, i) => _RunCard(run: runs[i]),
                ),
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  final SitePayrollRun run;
  const _RunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _RunPayslipsScreen(run: run)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            run.title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          if (run.clientName != null) ...[
            const SizedBox(height: 2),
            Text(run.clientName!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: [
              AppChip(
                label: run.statusLabel,
                tone: run.released ? AppColors.success : AppColors.warning,
              ),
              AppChip(
                label: run.people == 1 ? '1 person' : '${run.people} people',
                tone: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every payslip on one run that belongs to this site.
class _RunPayslipsScreen extends ConsumerWidget {
  final SitePayrollRun run;
  const _RunPayslipsScreen({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supervisorPayslipsProvider(run.id));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(run.title, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(supervisorPayslipsProvider(run.id)),
        child: async.when(
          loading: () => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: List.generate(
              6,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpace.md),
                child: SkeletonBox(height: 76, radius: AppRadius.lg),
              ),
            ),
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: [
              EmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Could not open this payroll',
                detail: e.toString().replaceFirst('Exception: ', ''),
              ),
            ],
          ),
          data: (detail) => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: [
              _Totals(detail: detail),
              const SizedBox(height: AppSpace.md),
              if (!detail.run.released)
                const _NotFinalNotice(),
              for (final slip in detail.payslips) ...[
                _PayslipCard(slip: slip),
                const SizedBox(height: AppSpace.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Said plainly, because a figure that can still move is worth a sentence.
class _NotFinalNotice extends StatelessWidget {
  const _NotFinalNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_bottom_rounded, size: 18, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Still going through approval. These figures can change until '
              'the Managing Director signs the run off.',
              style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final SitePayrollDetail detail;
  const _Totals({required this.detail});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();

    return AppCard(
      child: Row(
        children: [
          Expanded(child: _Figure(label: 'People', value: '${detail.payslips.length}')),
          Expanded(child: _Figure(label: 'Gross', value: money.format(detail.gross))),
          Expanded(
            child: _Figure(
              label: 'Net',
              value: money.format(detail.net),
              colour: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? colour;
  const _Figure({required this.label, required this.value, this.colour});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colour ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final SitePayslip slip;
  const _PayslipCard({required this.slip});

  /// Days read as people say them: 21, not 21.0, and 20.5 when it is a half.
  static String _days(double d) {
    final whole = d == d.roundToDouble();
    return whole ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();

    return AppCard(
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
                      slip.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [slip.empNumber, if (slip.role != null) slip.role!].join(' · '),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                money.format(slip.net),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.md,
            runSpacing: AppSpace.xs,
            children: [
              _Small(label: 'Days', value: _days(slip.workedDays)),
              if (slip.absentDays > 0)
                _Small(label: 'Missed', value: _days(slip.absentDays), warn: true),
              _Small(label: 'Gross', value: money.format(slip.gross)),
              _Small(label: 'Deductions', value: money.format(slip.deductions)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Small extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _Small({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: warn ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
