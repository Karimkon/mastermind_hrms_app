class AttendanceModel {
  final int id;
  final String? employee;
  final String? avatarUrl;
  final String? clockIn;
  final String? clockOut;
  final String? totalHours;
  final String status;
  final String date;

  const AttendanceModel({
    required this.id,
    this.employee,
    this.avatarUrl,
    this.clockIn,
    this.clockOut,
    this.totalHours,
    required this.status,
    required this.date,
  });

  bool get isClockedIn => clockIn != null && clockOut == null;
  bool get isClockedOut => clockIn != null && clockOut != null;

  factory AttendanceModel.fromJson(Map<String, dynamic> j) => AttendanceModel(
        id: j['id'],
        employee: j['employee_name'] ?? j['employee'],
        avatarUrl: j['avatar_url'],
        clockIn: j['clock_in'],
        clockOut: j['clock_out'],
        totalHours: (j['hours_worked'] ?? j['total_hours'])?.toString(),
        status: j['status'] ?? 'present',
        date: j['date'] ?? '',
      );
}
