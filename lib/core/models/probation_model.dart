class ProbationEmployeeModel {
  final int id;
  final String empNumber;
  final String fullName;
  final String? email;
  final String? avatarUrl;
  final String? department;
  final String? designation;
  final String? hireDate;
  final String? probationEndDate;
  final String? probationStatus;
  final String? probationConfirmedAt;
  final String? probationConfirmedBy;
  final int? daysLeft;
  final bool isOnProbation;
  final String? bio;

  const ProbationEmployeeModel({
    required this.id,
    required this.empNumber,
    required this.fullName,
    this.email,
    this.avatarUrl,
    this.department,
    this.designation,
    this.hireDate,
    this.probationEndDate,
    this.probationStatus,
    this.probationConfirmedAt,
    this.probationConfirmedBy,
    this.daysLeft,
    required this.isOnProbation,
    this.bio,
  });

  factory ProbationEmployeeModel.fromJson(Map<String, dynamic> j) =>
      ProbationEmployeeModel(
        id:                    j['id'],
        empNumber:             j['emp_number'] ?? '',
        fullName:              j['full_name'] ?? '',
        email:                 j['email'],
        avatarUrl:             j['avatar_url'],
        department:            j['department'],
        designation:           j['designation'],
        hireDate:              j['hire_date'],
        probationEndDate:      j['probation_end_date'],
        probationStatus:       j['probation_status'],
        probationConfirmedAt:  j['probation_confirmed_at'],
        probationConfirmedBy:  j['probation_confirmed_by'],
        daysLeft:              j['days_left'] as int?,
        isOnProbation:         j['is_on_probation'] ?? false,
        bio:                   j['bio'],
      );

  String get statusLabel => const {
    'on_probation': 'On Probation',
    'passed':       'Passed',
    'failed':       'Failed',
    'extended':     'Extended',
  }[probationStatus] ?? 'Not Set';

  bool get isOverdue {
    if (probationEndDate == null) return false;
    if (probationStatus == 'passed' || probationStatus == 'failed') return false;
    return DateTime.tryParse(probationEndDate!)?.isBefore(DateTime.now()) ?? false;
  }
}

class ProbationStatsModel {
  final int onProbation;
  final int passed;
  final int dueThisMonth;
  final int overdue;

  const ProbationStatsModel({
    required this.onProbation,
    required this.passed,
    required this.dueThisMonth,
    required this.overdue,
  });

  factory ProbationStatsModel.fromJson(Map<String, dynamic> j) =>
      ProbationStatsModel(
        onProbation:  j['onProbation'] ?? 0,
        passed:       j['passed'] ?? 0,
        dueThisMonth: j['dueThisMonth'] ?? 0,
        overdue:      j['overdue'] ?? 0,
      );
}
