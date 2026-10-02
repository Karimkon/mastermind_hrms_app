import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/careers_model.dart';
import '../../core/providers/careers_provider.dart';

/// The top of the careers home screen: who you are, and the two ways on.
class CareersHeader extends StatelessWidget {
  final CareersState state;
  const CareersHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final seeker = state.seeker;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 28,
                errorBuilder: (_, _, _) => const Text(
                  'MASTERMIND',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                ),
              ),
              const Spacer(),
              if (state.signedIn) ...[
                CareersNoticeBell(unread: state.unread),
                IconButton(
                  tooltip: 'My account',
                  onPressed: () => context.push('/careers/account'),
                  icon: const Icon(Icons.person_outline, color: Colors.white70),
                ),
              ] else
                TextButton.icon(
                  onPressed: () => context.push('/careers/sign-in'),
                  icon: const Icon(Icons.login, size: 17, color: Colors.white),
                  label: const Text('Sign in', style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            seeker == null
                ? 'Find work with Mastermind'
                : 'Welcome back, ${seeker.name.split(' ').first}',
            style: const TextStyle(
              color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            seeker == null
                ? 'Browse the vacancies below. Create an account to apply, and to be told when new jobs open in your line of work.'
                : 'You have ${seeker.applications} ${seeker.applications == 1 ? "application" : "applications"} with us.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    state.signedIn ? '/careers/applications' : '/careers/register',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC9A84C),
                    foregroundColor: const Color(0xFF1C1C1E),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: Icon(state.signedIn ? Icons.timeline : Icons.person_add_alt, size: 18),
                  label: Text(
                    state.signedIn ? 'My applications' : 'Create account',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/careers/track'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Track'),
                ),
              ),
            ],
          ),
          // The way to the employee side. Separate and clearly labelled, so
          // staff are not hunting for it and applicants are not confused.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
              ),
              icon: const Icon(Icons.badge_outlined, size: 16),
              label: const Text('Mastermind staff? Log in here', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class CareersNoticeBell extends StatelessWidget {
  final int unread;
  const CareersNoticeBell({super.key, required this.unread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/careers/notifications'),
          icon: const Icon(Icons.notifications_none, color: Colors.white70),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class CareersSearchBar extends ConsumerWidget {
  final TextEditingController controller;
  const CareersSearchBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void run() {
      final notifier = ref.read(careersProvider.notifier);
      notifier.setSearch(controller.text.trim());
      notifier.loadJobs();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => run(),
        decoration: InputDecoration(
          hintText: 'Search by job title or location',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward, size: 19), onPressed: run),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
        ),
      ),
    );
  }
}

class CareersCategoryChips extends ConsumerWidget {
  final CareersState state;
  const CareersCategoryChips({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: [
          _chip(context, ref, label: 'All jobs', selected: state.categoryFilter == null, id: null),
          ...state.categories.map((c) => _chip(
                context, ref,
                label: c.name,
                selected: state.categoryFilter == c.id,
                id: c.id,
              )),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, WidgetRef ref,
      {required String label, required bool selected, required int? id}) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        selected: selected,
        onSelected: (_) => ref.read(careersProvider.notifier).filterByCategory(selected ? null : id),
        showCheckmark: false,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.inputBorder),
      ),
    );
  }
}

/// The three categories most applied for. Useful to somebody deciding where
/// to put their effort, and it was asked for by name.
class CareersTopCategories extends StatelessWidget {
  final List<CategoryShare> shares;
  const CareersTopCategories({super.key, required this.shares});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Most applied for',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          const Text('Share of every application we have received',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 11),
          ...shares.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                        ),
                        Text('${_trim(s.percent)}%',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (s.percent / 100).clamp(0.02, 1.0),
                        minHeight: 5,
                        backgroundColor: AppColors.divider,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class CareersListHeading extends StatelessWidget {
  final CareersState state;
  const CareersListHeading({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final n = state.jobs.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Text(
            n == 0 ? 'Open positions' : '$n open ${n == 1 ? "position" : "positions"}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
          ),
          if (state.loadingJobs) ...[
            const SizedBox(width: 9),
            const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }
}

class CareersJobCard extends StatelessWidget {
  final CareerJob job;
  const CareersJobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final closing = job.closesInDays;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/careers/jobs/${job.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                  child: Text(
                    job.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textPrimary, height: 1.25),
                  ),
                ),
                if (job.alreadyApplied)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Applied',
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                  ),
              ],
            ),
            if (job.subtitle != null) ...[
              const SizedBox(height: 5),
              Text(job.subtitle!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                if (job.typeLabel.isNotEmpty) _tag(job.typeLabel, AppColors.infoLight, AppColors.primary),
                _tag('${job.applicants} ${job.applicants == 1 ? "applicant" : "applicants"}',
                    AppColors.divider, AppColors.textSecondary),
                _tag('${job.vacancies} ${job.vacancies == 1 ? "vacancy" : "vacancies"}',
                    AppColors.divider, AppColors.textSecondary),
                if (closing != null && closing >= 0)
                  _tag(
                    closing == 0 ? 'Closes today' : 'Closes in $closing ${closing == 1 ? "day" : "days"}',
                    closing <= 3 ? AppColors.warningLight : AppColors.divider,
                    closing <= 3 ? const Color(0xFF92400E) : AppColors.textSecondary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}

class CareersNoJobs extends StatelessWidget {
  const CareersNoJobs({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(32, 40, 32, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off_outlined, size: 46, color: AppColors.textMuted),
          SizedBox(height: 14),
          Text('No open positions right now',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          SizedBox(height: 6),
          Text(
            'New roles are posted regularly. Create an account and choose the kinds of work you want, and we will tell you when one opens.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class CareersProblem extends ConsumerWidget {
  final String message;
  const CareersProblem({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 14),
          const Text('Could not load the jobs',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(careersProvider.notifier).loadJobs(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
