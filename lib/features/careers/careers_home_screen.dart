import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/careers_provider.dart';
import 'careers_widgets.dart';

/// What the app opens on.
///
/// The old first screen was a login form, which told somebody who had just
/// installed the app nothing about why they had installed it - and was the
/// reason the App Store review saw only a login screen. The vacancies now
/// load before anything is asked of anybody; signing in is a button in the
/// corner, not a gate.
class CareersHomeScreen extends ConsumerStatefulWidget {
  const CareersHomeScreen({super.key});

  @override
  ConsumerState<CareersHomeScreen> createState() => _CareersHomeScreenState();
}

class _CareersHomeScreenState extends ConsumerState<CareersHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // After the first frame so the provider is not written to during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(careersProvider.notifier);
      notifier.loadJobs();
      notifier.loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(careersProvider.notifier).loadJobs(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: CareersHeader(state: state)),
              SliverToBoxAdapter(child: CareersSearchBar(controller: _searchController)),
              if (state.categories.isNotEmpty)
                SliverToBoxAdapter(child: CareersCategoryChips(state: state)),
              if (state.topCategories.isNotEmpty)
                SliverToBoxAdapter(child: CareersTopCategories(shares: state.topCategories)),
              SliverToBoxAdapter(child: CareersListHeading(state: state)),
              if (state.loadingJobs && state.jobs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.jobsError != null && state.jobs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: CareersProblem(message: state.jobsError!),
                )
              else if (state.jobs.isEmpty)
                const SliverFillRemaining(hasScrollBody: false, child: CareersNoJobs())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList.separated(
                    itemCount: state.jobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => CareersJobCard(job: state.jobs[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
