/// One day's overtime awaiting (or carrying) a decision.
///
/// Payroll pays [approvedHours] and nothing else, so [status] is what decides
/// whether this overtime is ever paid.
class OvertimeModel {
  final int id;
  final int employeeId;
  final String employeeName;
  final String? empNumber;
  final String? clientName;
  final String date;
  final double recordedHours;
  final double approvedHours;
  final String status;
  final String? approver;
  final String? approvedAt;
  final String? note;
  final double weekTotal;
  final bool exceedsDaily;
  final bool exceedsWeekly;

  const OvertimeModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.empNumber,
    this.clientName,
    required this.date,
    this.recordedHours = 0,
    this.approvedHours = 0,
    this.status = 'pending',
    this.approver,
    this.approvedAt,
    this.note,
    this.weekTotal = 0,
    this.exceedsDaily = false,
    this.exceedsWeekly = false,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  /// Flagged when the day or the week is over the company policy. The figure is
  /// a warning only — HR can still approve it.
  bool get breachesPolicy => exceedsDaily || exceedsWeekly;

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

  static int _toInt(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

  factory OvertimeModel.fromJson(Map<String, dynamic> j) => OvertimeModel(
        id: _toInt(j['id']),
        employeeId: _toInt(j['employee_id']),
        employeeName: j['employee_name']?.toString() ?? '—',
        empNumber: j['emp_number'] as String?,
        clientName: j['client_name'] as String?,
        date: j['date']?.toString() ?? '',
        recordedHours: _toDouble(j['recorded_hours']),
        approvedHours: _toDouble(j['approved_hours']),
        status: j['status']?.toString() ?? 'pending',
        approver: j['approver'] as String?,
        approvedAt: j['approved_at'] as String?,
        note: j['note'] as String?,
        weekTotal: _toDouble(j['week_total']),
        exceedsDaily: j['exceeds_daily'] == true,
        exceedsWeekly: j['exceeds_weekly'] == true,
      );
}

/// Company overtime policy, sent by the server so the app never hard-codes it.
class OvertimePolicy {
  final double dailyCap;
  final double weeklyCap;

  const OvertimePolicy({this.dailyCap = 2, this.weeklyCap = 12});

  factory OvertimePolicy.fromJson(Map<String, dynamic> j) => OvertimePolicy(
        dailyCap: OvertimeModel._toDouble(j['daily_cap']),
        weeklyCap: OvertimeModel._toDouble(j['weekly_cap']),
      );
}
