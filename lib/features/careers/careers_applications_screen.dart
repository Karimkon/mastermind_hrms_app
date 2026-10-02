import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/careers_model.dart';
import '../../core/providers/careers_provider.dart';
import 'application_progress.dart';

/// Everything a job seeker has applied for, and where each one stands.
class CareersApplicationsScreen extends ConsumerStatefulWidget {
  const CareersApplicationsScreen({super.key});

  @override
  ConsumerState<CareersApplicationsScreen> createState() =>
      _CareersApplicationsScreenState();
}

class _CareersApplicationsScreenState extends ConsumerState<CareersApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(careersProvider.notifier).loadApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My applications'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: !state.signedIn
          ? _signInPrompt(context)
          : RefreshIndicator(
              onRefresh: () => ref.read(careersProvider.notifier).loadApplications(),
              child: state.loadingApplications && state.applications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.applications.isEmpty
                      ? _empty(context)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                          itemCount: state.applications.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _ApplicationCard(application: state.applications[i]),
                        ),
            ),
    );
  }

  Widget _signInPrompt(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 44, color: AppColors.textMuted),
              const SizedBox(height: 14),
              const Text('Sign in to see your applications',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.push('/careers/sign-in'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );

  Widget _empty(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
        children: [
          const Icon(Icons.inbox_outlined, size: 46, color: AppColors.textMuted),
          const SizedBox(height: 14),
          const Center(
            child: Text('You have not applied for anything yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 7),
          const Center(
            child: Text('Once you apply, this is where you follow it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/careers'),
            child: const Text('Browse open positions'),
          ),
        ],
      );
}

class _ApplicationCard extends StatelessWidget {
  final JobApplication application;
  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final decided = application.isDecided;
    final outcome = application.progress.isEmpty ? null : application.progress.last;
    final notShortlisted = decided && (outcome?.label ?? '') == 'Not Shortlisted';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: application.id == null
          ? null
          : () => context.push('/careers/applications/${application.id}'),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
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
                      Text(application.jobTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              height: 1.25,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if ((application.jobLocation ?? '').isNotEmpty) application.jobLocation!,
                          'Ref ${application.trackingCode}',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: notShortlisted
                        ? AppColors.errorLight
                        : decided
                            ? AppColors.successLight
                            : AppColors.infoLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    decided ? (outcome?.label ?? 'Outcome') : application.stageLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: notShortlisted
                          ? const Color(0xFF991B1B)
                          : decided
                              ? const Color(0xFF065F46)
                              : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ApplicationProgress(stages: application.progress, compact: true),
            if (application.updates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                application.updates.first.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
