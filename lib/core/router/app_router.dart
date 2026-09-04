import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/mfa_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/employees/employees_screen.dart';
import '../../features/employees/employee_detail_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/leaves/leaves_screen.dart';
import '../../features/payroll/payroll_screen.dart';
import '../../features/payroll/my_payslips_screen.dart';
import '../../features/recruitment/jobs_screen.dart';
import '../../features/recruitment/candidates_screen.dart';
import '../../features/recruitment/interviews_screen.dart';
import '../../features/performance/performance_screen.dart';
import '../../features/training/training_screen.dart';
import '../../features/meetings/meetings_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/admin/users_screen.dart';
import '../../features/admin/departments_screen.dart';
import '../../features/admin/clients_screen.dart';
import '../../features/admin/audit_screen.dart';
import '../../features/client_portal/client_dashboard_screen.dart';
import '../../features/client_portal/client_leaves_screen.dart';
import '../../features/client_portal/client_recruitment_screen.dart';
import '../../features/documents/documents_screen.dart';
import '../../features/am_visits/am_visits_screen.dart';
import '../../features/office_attendance/office_attendance_screen.dart';
import '../../features/overtime/overtime_screen.dart';
import '../../features/am_visits/am_employees_screen.dart';
import '../../features/am_visits/am_leaves_screen.dart';
import '../../features/am_visits/am_payroll_screen.dart';
import '../../features/am_visits/am_salary_payments_screen.dart';
import '../../features/bsc/bsc_screen.dart';
import '../../features/bsc/bsc_my_appraisal_screen.dart';
import '../../features/probation/probation_screen.dart';
import '../../features/blog/screens/blog_screen.dart';
import '../../features/blog/screens/blog_detail_screen.dart';

// A ChangeNotifier that fires whenever auth state changes.
// GoRouter uses this via refreshListenable to re-evaluate redirects.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        notifyListeners();
      }
    });
  }
}

final _authRefreshProvider = Provider<ChangeNotifier>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  // Read the refresh notifier once (not watch) so the router is not recreated.
  final refreshListenable = ref.read(_authRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Use ref.read (not watch) — we only need the current value here.
      final loggedIn = ref.read(authProvider).isAuthenticated;
      final onAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/mfa');

      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/mfa',
        builder: (_, state) => MfaScreen(mfaToken: state.extra as String? ?? ''),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', redirect: (_, _) => '/dashboard'),
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(path: '/employees', builder: (_, _) => const EmployeesScreen()),
          GoRoute(
            path: '/employees/:id',
            builder: (_, state) => EmployeeDetailScreen(
              employeeId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/blog', builder: (_, _) => const BlogScreen()),
          GoRoute(
            path: '/blog/:slug',
            builder: (_, state) => BlogDetailScreen(
              slug: state.pathParameters['slug'] ?? '',
            ),
          ),
          GoRoute(path: '/attendance', builder: (_, _) => const AttendanceScreen()),
          GoRoute(path: '/leaves', builder: (_, _) => const LeavesScreen()),
          GoRoute(path: '/payroll', builder: (_, _) => const PayrollScreen()),
          GoRoute(path: '/my-payslips', builder: (_, _) => const MyPayslipsScreen()),
          GoRoute(path: '/recruitment/jobs', builder: (_, _) => const JobsScreen()),
          GoRoute(path: '/recruitment/candidates', builder: (_, _) => const CandidatesScreen()),
          GoRoute(path: '/recruitment/interviews', builder: (_, _) => const InterviewsScreen()),
          GoRoute(path: '/performance', builder: (_, _) => const PerformanceScreen()),
          GoRoute(path: '/training', builder: (_, _) => const TrainingScreen()),
          GoRoute(path: '/meetings', builder: (_, _) => const MeetingsScreen()),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
          GoRoute(path: '/admin/users', builder: (_, _) => const UsersScreen()),
          GoRoute(path: '/admin/departments', builder: (_, _) => const DepartmentsScreen()),
          GoRoute(path: '/admin/clients', builder: (_, _) => const AdminClientsScreen()),
          GoRoute(path: '/admin/audit', builder: (_, _) => const AuditScreen()),
          GoRoute(path: '/client/dashboard', builder: (_, _) => const ClientDashboardScreen()),
          GoRoute(path: '/client/leaves', builder: (_, _) => const ClientLeavesScreen()),
          GoRoute(path: '/client/recruitment', builder: (_, _) => const ClientRecruitmentScreen()),
          GoRoute(path: '/my-documents',       builder: (_, _) => const DocumentsScreen()),
          GoRoute(path: '/am-visits',            builder: (_, _) => const AmVisitsScreen()),
          // Office presence register — separate stream from site visits above,
          // and from /attendance which is the payroll-affecting one.
          GoRoute(path: '/office-attendance',    builder: (_, _) => const OfficeAttendanceScreen()),
          GoRoute(path: '/overtime',             builder: (_, _) => const OvertimeScreen()),
          GoRoute(path: '/am-employees',         builder: (_, _) => const AmEmployeesScreen()),
          GoRoute(path: '/am-leaves',            builder: (_, _) => const AmLeavesScreen()),
          GoRoute(path: '/am-payroll',           builder: (_, _) => const AmPayrollScreen()),
          GoRoute(path: '/am-salary-payments',  builder: (_, _) => const AmSalaryPaymentsScreen()),
          GoRoute(path: '/bsc',                 builder: (_, _) => const BscScreen()),
          GoRoute(path: '/bsc/my-appraisal',    builder: (_, _) => const BscMyAppraisalScreen()),
          GoRoute(path: '/probation',           builder: (_, _) => const ProbationScreen()),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
