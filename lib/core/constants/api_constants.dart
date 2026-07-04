class ApiConstants {
  static const String baseUrl = 'https://mastermind.autos/api';

  // Auth
  static const String login = '/auth/login';
  static const String mfaVerify = '/auth/mfa/verify';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Dashboard
  static const String dashboard = '/dashboard';

  // Profile
  static const String profile = '/profile';
  static const String profilePassword = '/profile/password';
  static const String profileAvatar = '/profile/avatar';

  // Employees
  static const String employees = '/employees';
  static const String departments = '/departments';
  static const String designations = '/designations';
  static const String clients = '/clients';

  // Attendance
  static const String attendance = '/attendance';
  static const String attendanceToday = '/attendance/today';
  static const String clockIn = '/attendance/clock-in';
  static const String clockOut = '/attendance/clock-out';
  static const String attendanceReport = '/attendance/report';

  // Leaves
  static const String leaves = '/leaves';
  static const String leaveTypes = '/leave-types';
  static const String leaveBalance = '/leave-balance';

  // Payroll
  static const String payroll = '/payroll';
  static const String myPayslips = '/my-payslips';

  // Recruitment
  static const String recruitmentJobs = '/recruitment/jobs';
  static const String recruitmentCandidates = '/recruitment/candidates';
  static const String recruitmentInterviews = '/recruitment/interviews';

  // Performance
  static const String performance = '/performance';
  static const String kpis = '/kpis';
  static const String goals = '/goals';
  static const String performanceCycles = '/performance/cycles';

  // Training
  static const String training = '/training';
  static const String certifications = '/certifications';

  // Meetings
  static const String meetings = '/meetings';
  static const String calendar = '/calendar';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsRead = '/notifications/read';

  // Reports
  static const String reportsEmployees = '/reports/employees';
  static const String reportsAttendance = '/reports/attendance';
  static const String reportsLeave = '/reports/leave';
  static const String reportsPayroll = '/reports/payroll';
  static const String reportsPerformance = '/reports/performance';
  static const String reportsTraining = '/reports/training';

  // Admin
  static const String adminUsers = '/admin/users';
  static const String adminDepartments = '/admin/departments';
  static const String adminRoles = '/admin/roles';
  static const String adminAudit = '/admin/audit';
  static const String adminClients = '/admin/clients';

  // Client portal
  static const String clientDashboard = '/client/dashboard';
  static const String clientLeaves = '/client/leaves';
  static const String clientRecruitment = '/client/recruitment';
  static const String clientJobs = '/client/jobs';

  // Employee self-service
  static const String myDocuments = '/my/documents';
  static const String myNok = '/my/nok';

  // AM Site Visits
  static const String amVisits       = '/am-visits';
  static const String amVisitClockIn = '/am-visits/clock-in';
  static const String amVisitClockOut= '/am-visits/clock-out';
  static const String amVisitActive  = '/am-visits/active';
  static const String amVisitClients = '/am-visits/clients';

  // Account Manager — Employees, Leaves & Payroll
  static const String amClients      = '/account-manager/clients';
  static const String amEmployees    = '/account-manager/employees';
  static const String amLeaves       = '/account-manager/leaves';
  static const String amPayroll         = '/account-manager/payroll';
  static const String amSalaryPayments  = '/account-manager/salary-payments';

  // BSC Appraisals
  static const String bscCycles       = '/bsc/cycles';
  static const String bscMyAppraisal  = '/bsc/my-appraisal';
  static const String bscTeamAppraisal= '/bsc/team-appraisal';
  static const String bscEntries      = '/bsc/entries';

  // Probation
  static const String probation = '/probation';
}
