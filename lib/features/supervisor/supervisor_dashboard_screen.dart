import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/supervisor_model.dart';
import '../../core/navigation/app_nav.dart';
import '../../core/providers/supervisor_provider.dart';
import '../../core/widgets/ui.dart';

/// What the supervised site looks like today.
///
/// The figure that matters is Unrecorded: the people nobody has said anything
/// about. Present and Absent are both answers; Unrecorded is the absence of
/// one, and it is the number this person is standing at the gate to drive to
/// zero. So it is the one that goes first and the one that turns amber.
class SupervisorDashboardScreen extends ConsumerWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supervisorDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(supervisorDashboardProvider),
        child: async.when(
          loading: () => const _Loading(),
          error: (e, _) => e is NoPostingException
              ? NoPostingNotice(message: e.message)
              : _Error(
                  message: e.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => ref.invalidate(supervisorDashboardProvider),
                ),
          data: (data) => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: [
              _SiteCard(data: data),
              const SizedBox(height: AppSpace.xl),

              const SectionLabel('Today'),
              CardGrid(
                minItemWidth: 150,
                gap: AppSpace.md,
                children: [
                  StatCard(
                    label: 'Not yet recorded',
                    value: '${data.stats.unrecorded}',
                    icon: Icons.help_outline_rounded,
                    tone: data.stats.unrecorded > 0
                        ? AppColors.warning
                        : AppColors.success,
                    onTap: () => AppNav.open(context, '/supervisor/workforce'),
                  ),
                  const SizedBox(width: AppSpace.md),
                  StatCard(
                    label: 'Present',
                    value: '${data.stats.present}',
                    icon: Icons.check_circle_rounded,
                    tone: AppColors.success,
                    onTap: () => AppNav.open(context, '/supervisor/workforce'),
                  ),
                  const SizedBox(width: AppSpace.md),
                  StatCard(
                    label: 'Absent',
                    value: '${data.stats.absent}',
                    icon: Icons.cancel_rounded,
                    tone: AppColors.error,
                    onTap: () => AppNav.open(context, '/supervisor/workforce'),
                  ),
                  const SizedBox(width: AppSpace.md),
                  StatCard(
                    label: 'Late',
                    value: '${data.stats.late}',
                    icon: Icons.schedule_rounded,
                    tone: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpace.md),
                  StatCard(
                    label: 'On leave',
                    value: '${data.stats.onLeave}',
                    icon: Icons.beach_access_rounded,
                    tone: AppColors.info,
                  ),
                  const SizedBox(width: AppSpace.md),
                  StatCard(
                    label: 'Still clocked in',
                    value: '${data.stats.stillIn}',
                    icon: Icons.timer_rounded,
                    tone: AppColors.primary,
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.xl),
              const SectionLabel('Go to'),
              AppCard(
                onTap: () => AppNav.open(context, '/supervisor/workforce'),
                child: const _Shortcut(
                  icon: Icons.groups_rounded,
                  title: 'My workforce',
                  detail: 'Everyone placed at your site, and how to reach them',
                ),
              ),
              const SizedBox(height: AppSpace.md),
              AppCard(
                onTap: () => AppNav.open(context, '/supervisor/requests'),
                child: const _Shortcut(
                  icon: Icons.fact_check_rounded,
                  title: 'My change requests',
                  detail: 'What you have sent the account manager, and what came of it',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final SupervisorDashboardModel data;
  const _SiteCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppColors.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded,
                  size: 15, color: Colors.white.withValues(alpha: 0.75)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  data.clients.isEmpty ? 'Your site' : data.clients.join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            '${data.stats.headcount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
          Text(
            data.stats.headcount == 1 ? 'person placed here' : 'people placed here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _Shortcut({required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 12, height: 1.35,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
        ],
      );
}

/// Shown when somebody holds the role but has no current posting.
///
/// The role grants the menu; a dated posting grants the site. An empty list
/// here would read as "nobody is at work today", which is a different and
/// much more alarming statement than "you have not been assigned anywhere".
class NoPostingNotice extends StatelessWidget {
  final String message;
  const NoPostingNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.all(AppSpace.page(context)),
        children: [
          EmptyState(
            icon: Icons.location_off_rounded,
            title: 'No site assigned to you',
            detail: message,
          ),
        ],
      );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.all(AppSpace.page(context)),
        children: [
          const SkeletonBox(height: 130, radius: AppRadius.xl),
          const SizedBox(height: AppSpace.xl),
          CardGrid(
            minItemWidth: 150,
            gap: AppSpace.md,
            children: const [
              SkeletonBox(height: 72, radius: AppRadius.lg),
              SizedBox(width: AppSpace.md),
              SkeletonBox(height: 72, radius: AppRadius.lg),
              SizedBox(width: AppSpace.md),
              SkeletonBox(height: 72, radius: AppRadius.lg),
              SizedBox(width: AppSpace.md),
              SkeletonBox(height: 72, radius: AppRadius.lg),
            ],
          ),
        ],
      );
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.all(AppSpace.page(context)),
        children: [
          EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your site',
            detail: message,
            action: FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ),
        ],
      );
}
