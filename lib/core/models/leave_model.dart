class LeaveRequestModel {
  final int id;
  final String? employee;
  final String? avatarUrl;
  final String leaveType;
  final String? leaveTypeColor;
  final String startDate;
  final String endDate;
  final int days;
  final String? reason;
  final String status;
  final String? clientApprovalStatus;
  final String createdAt;

  const LeaveRequestModel({
    required this.id,
    this.employee,
    this.avatarUrl,
    required this.leaveType,
    this.leaveTypeColor,
    required this.startDate,
    required this.endDate,
    required this.days,
    this.reason,
    required this.status,
    this.clientApprovalStatus,
    required this.createdAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> j) => LeaveRequestModel(
        id: j['id'],
        employee: j['employee_name'] ?? j['employee'],
        avatarUrl: j['employee_avatar'] ?? j['avatar_url'],
        leaveType: j['leave_type'] ?? '',
        leaveTypeColor: j['leave_type_color'],
        startDate: j['from_date'] ?? j['start_date'] ?? '',
        endDate: j['to_date'] ?? j['end_date'] ?? '',
        days: j['days_count'] ?? j['days'] ?? 0,
        reason: j['reason'],
        status: j['status'] ?? 'pending',
        clientApprovalStatus: j['client_approval_status'],
        createdAt: j['created_at'] ?? '',
      );
}

class LeaveTypeModel {
  final int id;
  final String name;
  final String? color;
  final int defaultDays;

  const LeaveTypeModel({
    required this.id,
    required this.name,
    this.color,
    required this.defaultDays,
  });

  factory LeaveTypeModel.fromJson(Map<String, dynamic> j) => LeaveTypeModel(
        id: j['id'],
        name: j['name'],
        color: j['color'],
        defaultDays: j['days_allowed'] ?? j['default_days'] ?? 0,
      );
}

class LeaveBalanceModel {
  final String type;
  final String? color;
  final int total;
  final int used;
  final int pending;
  final int remaining;

  const LeaveBalanceModel({
    required this.type,
    this.color,
    required this.total,
    required this.used,
    required this.pending,
    required this.remaining,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> j) => LeaveBalanceModel(
        type: j['type'] ?? '',
        color: j['color'],
        total: j['total_days'] ?? j['total'] ?? 0,
        used: j['used_days'] ?? j['used'] ?? 0,
        pending: j['pending_days'] ?? j['pending'] ?? 0,
        remaining: j['remaining'] ?? 0,
      );
}
