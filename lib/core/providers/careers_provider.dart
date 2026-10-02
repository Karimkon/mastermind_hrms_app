import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/careers_model.dart';
import '../services/careers_api.dart';

/// State for the careers side of the app.
///
/// The job list loads with no account at all, which is the point: somebody
/// who has just installed the app sees the vacancies before being asked for
/// anything. Signing in only adds their own applications on top.

class CareersState {
  final bool loadingJobs;
  final List<CareerJob> jobs;
  final List<JobCategoryModel> categories;
  final List<CategoryShare> topCategories;
  final int? categoryFilter;
  final String search;
  final String? jobsError;

  final SeekerProfile? seeker;
  final bool signedIn;

  final List<JobApplication> applications;
  final bool loadingApplications;

  final List<SeekerNotice> notices;
  final int unread;

  const CareersState({
    this.loadingJobs = false,
    this.jobs = const [],
    this.categories = const [],
    this.topCategories = const [],
    this.categoryFilter,
    this.search = '',
    this.jobsError,
    this.seeker,
    this.signedIn = false,
    this.applications = const [],
    this.loadingApplications = false,
    this.notices = const [],
    this.unread = 0,
  });

  CareersState copyWith({
    bool? loadingJobs,
    List<CareerJob>? jobs,
    List<JobCategoryModel>? categories,
    List<CategoryShare>? topCategories,
    int? categoryFilter,
    bool clearCategoryFilter = false,
    String? search,
    String? jobsError,
    bool clearJobsError = false,
    SeekerProfile? seeker,
    bool? signedIn,
    List<JobApplication>? applications,
    bool? loadingApplications,
    List<SeekerNotice>? notices,
    int? unread,
  }) {
    return CareersState(
      loadingJobs: loadingJobs ?? this.loadingJobs,
      jobs: jobs ?? this.jobs,
      categories: categories ?? this.categories,
      topCategories: topCategories ?? this.topCategories,
      categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      search: search ?? this.search,
      jobsError: clearJobsError ? null : (jobsError ?? this.jobsError),
      seeker: seeker ?? this.seeker,
      signedIn: signedIn ?? this.signedIn,
      applications: applications ?? this.applications,
      loadingApplications: loadingApplications ?? this.loadingApplications,
      notices: notices ?? this.notices,
      unread: unread ?? this.unread,
    );
  }
}

class CareersNotifier extends StateNotifier<CareersState> {
  CareersNotifier() : super(const CareersState()) {
    restore();
  }

  /// Pick up an existing session, if the seeker signed in before.
  Future<void> restore() async {
    if (!await CareersApi.hasToken) return;

    try {
      final data = await CareersApi.me();
      state = state.copyWith(
        seeker: SeekerProfile.fromJson(Map<String, dynamic>.from(data['seeker'] as Map)),
        signedIn: true,
      );
      await Future.wait([loadApplications(), loadNotices()]);
    } catch (_) {
      // A token the server no longer accepts is worse than none: it makes
      // every call fail with no way back. Drop it and carry on as a guest.
      await CareersApi.clearToken();
      state = state.copyWith(signedIn: false, seeker: null);
    }
  }

  Future<void> loadJobs({bool keepError = false}) async {
    state = state.copyWith(loadingJobs: true, clearJobsError: !keepError);

    try {
      final data = await CareersApi.jobs(
        categoryId: state.categoryFilter,
        search: state.search,
      );

      state = state.copyWith(
        loadingJobs: false,
        jobs: ((data['jobs'] as List?) ?? const [])
            .whereType<Map>()
            .map((j) => CareerJob.fromJson(Map<String, dynamic>.from(j)))
            .toList(),
        topCategories: ((data['top_categories'] as List?) ?? const [])
            .whereType<Map>()
            .map((c) => CategoryShare.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        clearJobsError: true,
      );
    } catch (e) {
      state = state.copyWith(loadingJobs: false, jobsError: e.toString());
    }
  }

  Future<void> loadCategories() async {
    if (state.categories.isNotEmpty) return;
    try {
      final data = await CareersApi.categories();
      state = state.copyWith(
        categories: ((data['categories'] as List?) ?? const [])
            .whereType<Map>()
            .map((c) => JobCategoryModel.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
      );
    } catch (_) {
      // The filter simply stays empty; the job list still works.
    }
  }

  void setSearch(String q) => state = state.copyWith(search: q);

  Future<void> filterByCategory(int? id) async {
    state = id == null
        ? state.copyWith(clearCategoryFilter: true)
        : state.copyWith(categoryFilter: id);
    await loadJobs();
  }

  // ---- account ----

  Future<void> register(Map<String, dynamic> body) async {
    final data = await CareersApi.register(body);
    await CareersApi.saveToken(data['token'] as String);
    state = state.copyWith(
      seeker: SeekerProfile.fromJson(Map<String, dynamic>.from(data['seeker'] as Map)),
      signedIn: true,
    );
    await Future.wait([loadJobs(), loadNotices()]);
  }

  Future<void> signIn(String email, String password) async {
    final data = await CareersApi.login(email, password);
    await CareersApi.saveToken(data['token'] as String);
    state = state.copyWith(
      seeker: SeekerProfile.fromJson(Map<String, dynamic>.from(data['seeker'] as Map)),
      signedIn: true,
    );
    await Future.wait([loadJobs(), loadApplications(), loadNotices()]);
  }

  Future<void> signOut() async {
    await CareersApi.logout();
    state = const CareersState();
    await loadJobs();
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    final data = await CareersApi.updateMe(body);
    state = state.copyWith(
      seeker: SeekerProfile.fromJson(Map<String, dynamic>.from(data['seeker'] as Map)),
    );
  }

  // ---- applications ----

  Future<void> loadApplications() async {
    if (!state.signedIn) return;
    state = state.copyWith(loadingApplications: true);

    try {
      final data = await CareersApi.applications();
      state = state.copyWith(
        loadingApplications: false,
        applications: ((data['applications'] as List?) ?? const [])
            .whereType<Map>()
            .map((a) => JobApplication.fromJson(Map<String, dynamic>.from(a)))
            .toList(),
      );
    } catch (_) {
      state = state.copyWith(loadingApplications: false);
    }
  }

  /// Called after a successful apply, so the list and the job both catch up.
  Future<void> afterApply() async {
    await Future.wait([loadJobs(), loadApplications(), loadNotices()]);
  }

  // ---- notifications ----

  Future<void> loadNotices() async {
    if (!state.signedIn) return;
    try {
      final data = await CareersApi.notifications();
      state = state.copyWith(
        unread: (data['unread'] ?? 0) as int,
        notices: ((data['notifications'] as List?) ?? const [])
            .whereType<Map>()
            .map((n) => SeekerNotice.fromJson(Map<String, dynamic>.from(n)))
            .toList(),
      );
    } catch (_) {
      // leave what we had
    }
  }

  Future<void> markAllRead() async {
    if (!state.signedIn || state.unread == 0) return;
    try {
      await CareersApi.markRead();
      state = state.copyWith(unread: 0);
      await loadNotices();
    } catch (_) {}
  }
}

final careersProvider = StateNotifierProvider<CareersNotifier, CareersState>(
  (ref) => CareersNotifier(),
);
