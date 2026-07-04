import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/dashboard_provider.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/models/attendance_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;
    final dashAsync = ref.watch(dashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting + Clock In (for employees)
          _GreetingCard(user: user),
          const SizedBox(height: 24),

          // Role-specific dashboard content
          dashAsync.when(
            loading: () => const _DashboardSkeleton(),
            error: (e, _) => _ErrorCard(message: e.toString()),
            data: (data) {
              if (user.isClient) return _ClientDashboard(data: data);
              if (user.isAdmin) return _AdminDashboard(data: data, ref: ref);
              if (user.isPayroll) return _PayrollDashboard(data: data);
              if (user.isRecruiter) return _RecruiterDashboard(data: data);
              if (user.isAccountManager) return _AccountManagerDashboard(data: data, user: user);
              return _EmployeeDashboard(data: data, user: user, ref: ref);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────── Greeting Card ───────────────
class _GreetingCard extends ConsumerWidget {
  final dynamic user;
  const _GreetingCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final emoji = hour < 12 ? '☀️' : hour < 17 ? '🌤️' : '🌙';
    final todayAsync = ref.watch(attendanceTodayProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${user.name.split(' ').first} $emoji',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.employee?.designation ?? _roleLabel(user.roles.isNotEmpty ? user.roles.first : '')} · ${DateFormat('EEEE, MMM d, yyyy').format(now)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                ),
              ],
            ),
          ),
          // Clock in/out button for employees (not for AM, admin, or client)
          if (!user.isAdmin && !user.isClient && !user.isAccountManager)
            todayAsync.when(
              loading: () => const SizedBox(width: 120, child: Center(child: CircularProgressIndicator(color: Colors.white))),
              error: (_, __) => const SizedBox.shrink(),
              data: (state) => _ClockButton(today: state.log, ref: ref),
            ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    const map = {
      'super-admin': 'Super Admin',
      'hr-admin': 'HR Admin',
      'payroll-officer': 'Payroll Officer',
      'recruiter': 'Recruiter',
      'manager': 'Manager',
      'account-manager': 'Account Manager',
      'employee': 'Employee',
      'client': 'Client',
    };
    return map[role] ?? role;
  }
}

class _ClockButton extends StatelessWidget {
  final AttendanceModel? today;
  final WidgetRef ref;
  const _ClockButton({required this.today, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isClockedIn = today?.isClockedIn ?? false;
    final isClockedOut = today?.isClockedOut ?? false;

    if (isClockedOut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text('In: ${today!.clockIn!}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('Out: ${today!.clockOut!}', style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () async {
        if (isClockedIn) {
          await ref.read(attendanceTodayProvider.notifier).clockOut();
        } else {
          await ref.read(attendanceTodayProvider.notifier).clockIn();
        }
      },
      icon: Icon(isClockedIn ? Icons.logout_rounded : Icons.login_rounded, size: 18),
      label: Text(isClockedIn ? 'Clock Out' : 'Clock In'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isClockedIn ? AppColors.error : Colors.white,
        foregroundColor: isClockedIn ? Colors.white : AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─────────────── Employee Dashboard ───────────────
class _EmployeeDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  final dynamic user;
  final WidgetRef ref;
  const _EmployeeDashboard({required this.data, required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final attendance = data['attendance'] as Map<String, dynamic>? ?? {};
    final balances = data['leave_balances'] as List? ?? [];
    final pendingLeaves = data['pending_leaves'] as List? ?? [];
    final payslips = data['recent_payslips'] as List? ?? [];
    final trainings = data['training'] as List? ?? [];
    final meetings = data['upcoming_meetings'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attendance stats
        _StatCardGrid(cards: [
            _StatCard(
              value: '${attendance['present'] ?? 0}',
              label: 'Present This Month',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              bg: AppColors.successLight,
            ),
            _StatCard(
              value: '${attendance['absent'] ?? 0}',
              label: 'Absent This Month',
              icon: Icons.cancel_rounded,
              color: AppColors.error,
              bg: AppColors.errorLight,
            ),
            _StatCard(
              value: '${attendance['late'] ?? 0}',
              label: 'Late This Month',
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
              bg: AppColors.warningLight,
            ),
            _StatCard(
              value: '${attendance['today_hours'] ?? '0h'}',
              label: "Today's Hours",
              icon: Icons.timer_rounded,
              color: AppColors.info,
              bg: AppColors.infoLight,
            ),
          ]),
        const SizedBox(height: 24),

        // 3-column grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leave balances
            Expanded(
              child: _DashCard(
                title: 'My Leave Balances',
                action: TextButton(
                  onPressed: () => context.go('/leaves'),
                  child: const Text('Apply for leave', style: TextStyle(fontSize: 12)),
                ),
                child: Column(
                  children: balances.isEmpty
                      ? [const _EmptyState(icon: Icons.beach_access_rounded, label: 'No leave types')]
                      : balances.map((b) {
                          final total = (b['total'] ?? 0) as int;
                          final used = (b['used'] ?? 0) as int;
                          final remaining = (b['remaining'] ?? 0) as int;
                          final pct = total > 0 ? used / total : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(b['type'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                    Text('$used / $total used', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct.clamp(0.0, 1.0),
                                    backgroundColor: AppColors.surface,
                                    color: AppColors.primary,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('$remaining days remaining', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Pending leave requests
            Expanded(
              child: _DashCard(
                title: 'My Leave Requests',
                action: TextButton(
                  onPressed: () => context.go('/leaves'),
                  child: const Text('+ New request', style: TextStyle(fontSize: 12)),
                ),
                child: pendingLeaves.isEmpty
                    ? const _EmptyState(icon: Icons.event_busy_rounded, label: 'No leave requests yet')
                    : Column(
                        children: pendingLeaves.take(4).map((l) => _LeaveRequestTile(leave: l)).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),

            // Payslips
            Expanded(
              child: _DashCard(
                title: 'My Payslips',
                action: TextButton(
                  onPressed: () => context.go('/my-payslips'),
                  child: const Text('View all', style: TextStyle(fontSize: 12)),
                ),
                child: payslips.isEmpty
                    ? const _EmptyState(icon: Icons.receipt_long_rounded, label: 'No payslips yet')
                    : Column(
                        children: payslips.take(3).map((p) => _PayslipTile(payslip: p)).toList(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Training & Meetings row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DashCard(
                title: 'My Training',
                action: TextButton(
                  onPressed: () => context.go('/training'),
                  child: const Text('Browse courses', style: TextStyle(fontSize: 12)),
                ),
                child: trainings.isEmpty
                    ? const _EmptyState(icon: Icons.school_rounded, label: 'Not enrolled in any training')
                    : Column(
                        children: trainings.take(3).map((t) => _TrainingTile(training: t)).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DashCard(
                title: 'Upcoming Meetings',
                action: TextButton(
                  onPressed: () => context.go('/meetings'),
                  child: const Text('View calendar', style: TextStyle(fontSize: 12)),
                ),
                child: meetings.isEmpty
                    ? const _EmptyState(icon: Icons.calendar_today_rounded, label: 'No upcoming meetings')
                    : Column(
                        children: meetings.take(4).map((m) => _MeetingTile(meeting: m)).toList(),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────── Account Manager Dashboard ───────────────
class _AccountManagerDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  final dynamic user;
  const _AccountManagerDashboard({required this.data, required this.user});

  @override
  Widget build(BuildContext context) {
    final stats         = data['stats'] as Map<String, dynamic>? ?? {};
    final pendingLeaves = data['pending_leaves'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats grid
        _StatCardGrid(cards: [
            _StatCard(
              value: '${stats['total_clients'] ?? 0}',
              label: 'Managed Clients',
              icon: Icons.business_rounded,
              color: AppColors.primary,
              bg: AppColors.infoLight,
            ),
            _StatCard(
              value: '${stats['total_employees'] ?? 0}',
              label: 'Total Employees',
              icon: Icons.people_rounded,
              color: AppColors.success,
              bg: AppColors.successLight,
            ),
            _StatCard(
              value: '${stats['pending_leaves'] ?? 0}',
              label: 'Pending Leaves',
              icon: Icons.event_busy_rounded,
              color: AppColors.warning,
              bg: AppColors.warningLight,
            ),
            _StatCard(
              value: '${stats['expiring_docs'] ?? 0}',
              label: 'Expiring Documents',
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
              bg: AppColors.errorLight,
            ),
          ]),
        const SizedBox(height: 24),

        // Quick Actions
        _DashCard(
          title: 'Quick Actions',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickAction(
                label: 'Employees',
                icon: Icons.badge_rounded,
                color: AppColors.primary,
                bg: AppColors.infoLight,
                onTap: () => context.go('/am-employees'),
              ),
              _QuickAction(
                label: 'Leave Requests',
                icon: Icons.event_available_rounded,
                color: AppColors.warning,
                bg: AppColors.warningLight,
                onTap: () => context.go('/am-leaves'),
              ),
              _QuickAction(
                label: 'Payroll',
                icon: Icons.payments_rounded,
                color: AppColors.success,
                bg: AppColors.successLight,
                onTap: () => context.go('/am-payroll'),
              ),
              _QuickAction(
                label: 'Site Visits',
                icon: Icons.location_on_rounded,
                color: const Color(0xFF8B5CF6),
                bg: const Color(0xFFF5F3FF),
                onTap: () => context.go('/am-visits'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pending leave requests
        _DashCard(
          title: 'Pending Leave Requests',
          action: TextButton(
            onPressed: () => context.go('/am-leaves'),
            child: const Text('View all', style: TextStyle(fontSize: 12)),
          ),
          child: pendingLeaves.isEmpty
              ? const _EmptyState(icon: Icons.beach_access_rounded, label: 'No pending leave requests')
              : Column(
                  children: pendingLeaves.take(5).map((l) => _AdminLeaveRow(leave: Map<String, dynamic>.from(l))).toList(),
                ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.icon, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────── Admin Dashboard ───────────────
class _AdminDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  final WidgetRef ref;
  const _AdminDashboard({required this.data, required this.ref});

  @override
  Widget build(BuildContext context) {
    final stats = data['stats'] as Map<String, dynamic>? ?? data;
    final attendance = data['attendance'] as Map<String, dynamic>? ?? {};
    final pendingLeaves = data['pending_leaves'] as List? ?? [];
    final deptBreakdown = data['department_breakdown'] as List? ?? [];
    final recentActivities = data['recent_activities'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top stats
        _StatCardGrid(cards: [
            _StatCard(value: '${stats['total_employees'] ?? stats['employees'] ?? 0}', label: 'Total Employees', icon: Icons.people_rounded, color: AppColors.primary, bg: AppColors.infoLight),
            _StatCard(value: '${stats['attendance_rate'] ?? attendance['rate'] ?? '0'}%', label: 'Attendance Rate', icon: Icons.fingerprint_rounded, color: AppColors.success, bg: AppColors.successLight),
            _StatCard(value: '${stats['pending_leaves'] ?? pendingLeaves.length}', label: 'Pending Leaves', icon: Icons.event_busy_rounded, color: AppColors.warning, bg: AppColors.warningLight),
            _StatCard(value: 'UGX ${_fmt(stats['monthly_payroll'] ?? 0)}', label: 'Monthly Payroll', icon: Icons.payments_rounded, color: const Color(0xFF8B5CF6), bg: const Color(0xFFF5F3FF)),
          ]),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _DashCard(
                title: 'Pending Leave Requests',
                action: TextButton(onPressed: () => context.go('/leaves'), child: const Text('View all', style: TextStyle(fontSize: 12))),
                child: pendingLeaves.isEmpty
                    ? const _EmptyState(icon: Icons.beach_access_rounded, label: 'No pending requests')
                    : Column(
                        children: pendingLeaves.take(5).map((l) => _AdminLeaveRow(leave: l)).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DashCard(
                title: 'Department Overview',
                child: deptBreakdown.isEmpty
                    ? const _EmptyState(icon: Icons.corporate_fare_rounded, label: 'No data')
                    : Column(
                        children: deptBreakdown.take(6).map((d) => _DeptRow(dept: d)).toList(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DashCard(
          title: 'Recent Activities',
          child: recentActivities.isEmpty
              ? const _EmptyState(icon: Icons.history_rounded, label: 'No recent activity')
              : Column(
                  children: recentActivities.take(8).map((a) => _ActivityRow(activity: a)).toList(),
                ),
        ),
      ],
    );
  }

  String _fmt(dynamic val) {
    try {
      final n = double.parse(val.toString());
      if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
      if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
      return n.toStringAsFixed(0);
    } catch (_) {
      return val.toString();
    }
  }
}

// ─────────────── Payroll Dashboard ───────────────
class _PayrollDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PayrollDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = data['stats'] as Map<String, dynamic>? ?? data;
    final recent = data['recent_payrolls'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatCardGrid(cards: [
            _StatCard(value: '${stats['employees_on_payroll'] ?? 0}', label: 'On Payroll', icon: Icons.people_rounded, color: AppColors.primary, bg: AppColors.infoLight),
            _StatCard(value: 'UGX ${stats['last_month_total'] ?? 0}', label: 'Last Month Total', icon: Icons.payments_rounded, color: AppColors.success, bg: AppColors.successLight),
            _StatCard(value: '${stats['pending_runs'] ?? 0}', label: 'Pending Runs', icon: Icons.pending_actions_rounded, color: AppColors.warning, bg: AppColors.warningLight),
          ]),
        const SizedBox(height: 24),
        _DashCard(
          title: 'Recent Payroll Runs',
          action: TextButton(onPressed: () => context.go('/payroll'), child: const Text('View all', style: TextStyle(fontSize: 12))),
          child: recent.isEmpty
              ? const _EmptyState(icon: Icons.payments_rounded, label: 'No payroll runs yet')
              : Column(children: recent.take(5).map((p) => _PayrollRunRow(run: p)).toList()),
        ),
      ],
    );
  }
}

// ─────────────── Recruiter Dashboard ───────────────
class _RecruiterDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecruiterDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = data['stats'] as Map<String, dynamic>? ?? data;
    final openJobs = data['open_jobs'] as List? ?? [];
    final recentCandidates = data['recent_candidates'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatCardGrid(cards: [
            _StatCard(value: '${stats['open_jobs'] ?? openJobs.length}', label: 'Open Jobs', icon: Icons.work_rounded, color: AppColors.primary, bg: AppColors.infoLight),
            _StatCard(value: '${stats['total_candidates'] ?? 0}', label: 'Total Candidates', icon: Icons.person_search_rounded, color: AppColors.success, bg: AppColors.successLight),
            _StatCard(value: '${stats['interviews_today'] ?? 0}', label: 'Interviews Today', icon: Icons.record_voice_over_rounded, color: AppColors.warning, bg: AppColors.warningLight),
            _StatCard(value: '${stats['offers_pending'] ?? 0}', label: 'Offers Pending', icon: Icons.send_rounded, color: const Color(0xFF8B5CF6), bg: const Color(0xFFF5F3FF)),
          ]),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DashCard(
                title: 'Open Job Postings',
                action: TextButton(onPressed: () => context.go('/recruitment/jobs'), child: const Text('View all', style: TextStyle(fontSize: 12))),
                child: openJobs.isEmpty
                    ? const _EmptyState(icon: Icons.work_outline_rounded, label: 'No open jobs')
                    : Column(children: openJobs.take(5).map((j) => _JobRow(job: j)).toList()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DashCard(
                title: 'Recent Candidates',
                action: TextButton(onPressed: () => context.go('/recruitment/candidates'), child: const Text('View all', style: TextStyle(fontSize: 12))),
                child: recentCandidates.isEmpty
                    ? const _EmptyState(icon: Icons.person_search_rounded, label: 'No candidates yet')
                    : Column(children: recentCandidates.take(5).map((c) => _CandidateRow(candidate: c)).toList()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────── Client Dashboard ───────────────
class _ClientDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ClientDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pendingLeaves = data['pending_leaves'] as List? ?? [];
    final pendingCandidates = data['pending_candidates'] as List? ?? [];

    return Column(
      children: [
        _StatCardGrid(cards: [
            _StatCard(value: '${pendingLeaves.length}', label: 'Leave Approvals', icon: Icons.event_busy_rounded, color: AppColors.warning, bg: AppColors.warningLight),
            _StatCard(value: '${pendingCandidates.length}', label: 'Candidates to Review', icon: Icons.person_search_rounded, color: AppColors.primary, bg: AppColors.infoLight),
          ]),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DashCard(
                title: 'Pending Leave Requests',
                action: TextButton(onPressed: () => context.go('/client/leaves'), child: const Text('View all', style: TextStyle(fontSize: 12))),
                child: pendingLeaves.isEmpty
                    ? const _EmptyState(icon: Icons.beach_access_rounded, label: 'No pending requests')
                    : Column(children: pendingLeaves.take(5).map((l) => _AdminLeaveRow(leave: l)).toList()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _DashCard(
                title: 'Candidates Awaiting Review',
                action: TextButton(onPressed: () => context.go('/client/recruitment'), child: const Text('View all', style: TextStyle(fontSize: 12))),
                child: pendingCandidates.isEmpty
                    ? const _EmptyState(icon: Icons.person_search_rounded, label: 'No candidates pending')
                    : Column(children: pendingCandidates.take(5).map((c) => _CandidateRow(candidate: c)).toList()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────── Shared Widgets ───────────────
class _StatCardGrid extends StatelessWidget {
  final List<Widget> cards;
  const _StatCardGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth < 600 ? 2 : cards.length;
      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += perRow) {
        if (i > 0) rows.add(const SizedBox(height: 12));
        final end = (i + perRow).clamp(0, cards.length);
        final slice = cards.sublist(i, end);
        rows.add(Row(
          children: [
            for (var j = 0; j < perRow; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              j < slice.length
                  ? Expanded(child: slice[j])
                  : const Expanded(child: SizedBox()),
            ],
          ],
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
    });
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _DashCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _LeaveRequestTile extends StatelessWidget {
  final Map<String, dynamic> leave;
  const _LeaveRequestTile({required this.leave});

  @override
  Widget build(BuildContext context) {
    final status = leave['status'] as String? ?? 'pending';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leave['leave_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${leave['from_date'] ?? leave['start_date'] ?? ''} → ${leave['to_date'] ?? leave['end_date'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          _StatusBadge(status: status),
        ],
      ),
    );
  }
}

class _PayslipTile extends StatelessWidget {
  final Map<String, dynamic> payslip;
  const _PayslipTile({required this.payslip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.description_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(payslip['period'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text('UGX ${_fmt(payslip['net_pay'] ?? 0)}',
              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          const Text('PDF', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _fmt(dynamic val) {
    try {
      final n = double.parse(val.toString());
      final fmt = NumberFormat('#,##0', 'en');
      return fmt.format(n);
    } catch (_) {
      return val.toString();
    }
  }
}

class _TrainingTile extends StatelessWidget {
  final Map<String, dynamic> training;
  const _TrainingTile({required this.training});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.school_rounded, size: 18, color: AppColors.info),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(training['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                Text('${training['duration'] ?? ''} · ${training['mode'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingTile extends StatelessWidget {
  final Map<String, dynamic> meeting;
  const _MeetingTile({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.video_call_rounded, size: 18, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meeting['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                Text(meeting['scheduled_at'] ?? meeting['date'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLeaveRow extends StatelessWidget {
  final Map<String, dynamic> leave;
  const _AdminLeaveRow({required this.leave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.infoLight,
            child: Text(
              (leave['employee'] as String? ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leave['employee'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${leave['leave_type'] ?? ''} · ${leave['days'] ?? 0} days', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          _StatusBadge(status: leave['status'] ?? 'pending'),
        ],
      ),
    );
  }
}

class _DeptRow extends StatelessWidget {
  final Map<String, dynamic> dept;
  const _DeptRow({required this.dept});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(dept['name'] ?? '', style: const TextStyle(fontSize: 13))),
          Text('${dept['count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const Text(' employees', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(activity['description'] ?? activity['event'] ?? '', style: const TextStyle(fontSize: 13))),
          Text(activity['time'] ?? activity['created_at'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _PayrollRunRow extends StatelessWidget {
  final Map<String, dynamic> run;
  const _PayrollRunRow({required this.run});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(run['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Text('${run['employee_count'] ?? 0} emp', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          _StatusBadge(status: run['status'] ?? 'draft'),
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  final Map<String, dynamic> job;
  const _JobRow({required this.job});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(job['department'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text('${job['candidates_count'] ?? 0} candidates', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final Map<String, dynamic> candidate;
  const _CandidateRow({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.infoLight,
            child: Text(
              (candidate['name'] as String? ?? '?')[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(candidate['job_title'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text('${candidate['score'] ?? 0}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status.toLowerCase()) {
      'approved' || 'active' || 'present' || 'completed' || 'processed' => (AppColors.successLight, AppColors.success),
      'pending' || 'draft' || 'scheduled' => (AppColors.warningLight, AppColors.warning),
      'rejected' || 'absent' || 'cancelled' => (AppColors.errorLight, AppColors.error),
      _ => (AppColors.infoLight, AppColors.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  Widget _box({double height = 88, double? width, BorderRadius? radius}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: radius ?? BorderRadius.circular(12),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat cards row
          Row(children: List.generate(4, (i) => Expanded(child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 16 : 0),
            child: _box(height: 88),
          )))),
          const SizedBox(height: 24),
          // Chart area
          _box(height: 220),
          const SizedBox(height: 24),
          // Two columns
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _box(height: 180)),
            const SizedBox(width: 16),
            Expanded(child: _box(height: 180)),
          ]),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text('Could not load dashboard: $message', style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }
}
