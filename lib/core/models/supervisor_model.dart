import '../services/json_num.dart';

/// The field supervisor's workforce, as the API hands it over.
///
/// Everything here is already scoped by the server to the supervisor's
/// current postings. Nothing in this file filters anything — if a row arrived
/// it is one of theirs, and re-deciding that on the phone would only create a
/// second opinion to go wrong.

class SupervisorStatsModel {
  final int headcount;
  final int present;
  final int absent;
  final int late;
  final int halfDay;
  final int onLeave;

  /// Nobody has said anything about these people today: not marked present,
  /// not marked absent, not on leave. It is the number the supervisor is
  /// actually there to drive to zero.
  final int unrecorded;

  /// Clocked in and not yet out.
  final int stillIn;

  const SupervisorStatsModel({
    this.headcount = 0,
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.halfDay = 0,
    this.onLeave = 0,
    this.unrecorded = 0,
    this.stillIn = 0,
  });

  factory SupervisorStatsModel.fromJson(Map<String, dynamic> j) => SupervisorStatsModel(
        headcount: asInt(j['headcount']),
        present: asInt(j['present']),
        absent: asInt(j['absent']),
        late: asInt(j['late']),
        halfDay: asInt(j['half_day']),
        onLeave: asInt(j['on_leave']),
        unrecorded: asInt(j['unrecorded']),
        stillIn: asInt(j['still_in']),
      );
}

class SupervisorDashboardModel {
  final String date;
  final List<String> clients;
  final SupervisorStatsModel stats;

  const SupervisorDashboardModel({
    required this.date,
    required this.clients,
    required this.stats,
  });

  factory SupervisorDashboardModel.fromJson(Map<String, dynamic> j) => SupervisorDashboardModel(
        date: (j['date'] ?? '').toString(),
        clients: ((j['clients'] as List?) ?? const [])
            .map((c) => (c['company_name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList(),
        stats: SupervisorStatsModel.fromJson(
            Map<String, dynamic>.from(j['stats'] as Map? ?? const {})),
      );
}

/// Today's attendance for one person, or null when nothing has been recorded.
class SupervisorTodayModel {
  final String? status;
  final String? clockIn;
  final String? clockOut;

  const SupervisorTodayModel({this.status, this.clockIn, this.clockOut});

  factory SupervisorTodayModel.fromJson(Map<String, dynamic> j) => SupervisorTodayModel(
        status: j['status']?.toString(),
        clockIn: j['clock_in']?.toString(),
        clockOut: j['clock_out']?.toString(),
      );
}

class SupervisorEmployeeModel {
  final int id;
  final String name;
  final String empNumber;
  final String staffNumber;
  final String? designation;
  final String? department;
  final String? client;
  final String status;
  final SupervisorTodayModel? today;

  /// Present only on the detail call, which is why they are all nullable:
  /// the list endpoint does not carry them and must not pretend to.
  final String? phone;
  final String? personalEmail;
  final String? hireDate;

  const SupervisorEmployeeModel({
    required this.id,
    required this.name,
    required this.empNumber,
    required this.staffNumber,
    this.designation,
    this.department,
    this.client,
    this.status = 'active',
    this.today,
    this.phone,
    this.personalEmail,
    this.hireDate,
  });

  factory SupervisorEmployeeModel.fromJson(Map<String, dynamic> j) => SupervisorEmployeeModel(
        id: asInt(j['id']),
        name: (j['name'] ?? '').toString(),
        empNumber: (j['emp_number'] ?? '').toString(),
        staffNumber: (j['staff_number'] ?? '').toString(),
        designation: j['designation']?.toString(),
        department: j['department']?.toString(),
        client: j['client']?.toString(),
        status: (j['status'] ?? 'active').toString(),
        today: j['today'] == null
            ? null
            : SupervisorTodayModel.fromJson(Map<String, dynamic>.from(j['today'] as Map)),
        phone: j['phone']?.toString(),
        personalEmail: j['personal_email']?.toString(),
        hireDate: j['hire_date']?.toString(),
      );
}

/// One field the supervisor may propose a new value for.
class EditableFieldModel {
  final String name;
  final String label;
  final String? value;
  final String type;

  const EditableFieldModel({
    required this.name,
    required this.label,
    this.value,
    this.type = 'text',
  });

  factory EditableFieldModel.fromJson(Map<String, dynamic> j) => EditableFieldModel(
        name: (j['name'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        value: j['value']?.toString(),
        type: (j['type'] ?? 'text').toString(),
      );
}

/// What the server will accept right now, and what it wants said first.
///
/// Read from the API rather than written into the app: the field list and
/// the "one at a time" rule are policy, and policy baked into a shipped
/// build cannot be corrected without another release.
/// A headed set of fields, as the form is laid out.
class EditableGroupModel {
  final String heading;
  final List<EditableFieldModel> fields;

  const EditableGroupModel({required this.heading, this.fields = const []});

  factory EditableGroupModel.fromJson(Map<String, dynamic> j) => EditableGroupModel(
        heading: (j['heading'] ?? '').toString(),
        fields: ((j['fields'] as List?) ?? const [])
            .map((f) => EditableFieldModel.fromJson(Map<String, dynamic>.from(f as Map)))
            .toList(),
      );
}

class EditableContractModel {
  /// Every field, flat. Kept because it is what the first build of
  /// this screen read, and a server that stops sending it would break
  /// an app already on somebody's phone.
  final List<EditableFieldModel> fields;

  /// The same fields, in the sections the web form uses. Forty boxes
  /// in one column is not a form anybody completes on a phone.
  final List<EditableGroupModel> groups;

  final bool canPropose;
  final String notice;
  final PendingChangeModel? pending;

  const EditableContractModel({
    this.fields = const [],
    this.groups = const [],
    this.canPropose = false,
    this.notice = '',
    this.pending,
  });

  /// The sections to draw. Falls back to one unnamed group holding the
  /// flat list, so an older server that sends no groups still renders.
  List<EditableGroupModel> get sections => groups.isNotEmpty
      ? groups
      : [EditableGroupModel(heading: 'Details', fields: fields)];

  factory EditableContractModel.fromJson(Map<String, dynamic> j) => EditableContractModel(
        fields: ((j['fields'] as List?) ?? const [])
            .map((f) => EditableFieldModel.fromJson(Map<String, dynamic>.from(f as Map)))
            .toList(),
        groups: ((j['groups'] as List?) ?? const [])
            .map((g) => EditableGroupModel.fromJson(Map<String, dynamic>.from(g as Map)))
            .toList(),
        canPropose: j['can_propose'] == true,
        notice: (j['notice'] ?? '').toString(),
        pending: j['pending'] == null
            ? null
            : PendingChangeModel.fromJson(Map<String, dynamic>.from(j['pending'] as Map)),
      );
}

class PendingChangeModel {
  final int id;
  final String? label;
  final String? client;
  final String status;
  final List<String> fields;
  final String? requestedBy;
  final String? requestedAt;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? reviewNote;

  const PendingChangeModel({
    required this.id,
    this.label,
    this.client,
    this.status = 'pending',
    this.fields = const [],
    this.requestedBy,
    this.requestedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory PendingChangeModel.fromJson(Map<String, dynamic> j) => PendingChangeModel(
        id: asInt(j['id']),
        label: j['label']?.toString(),
        client: j['client']?.toString(),
        status: (j['status'] ?? 'pending').toString(),
        fields: ((j['fields'] as List?) ?? const []).map((f) => f.toString()).toList(),
        requestedBy: j['requested_by']?.toString(),
        requestedAt: j['requested_at']?.toString(),
        reviewedBy: j['reviewed_by']?.toString(),
        reviewedAt: j['reviewed_at']?.toString(),
        reviewNote: j['review_note']?.toString(),
      );
}

/// One employee with everything the detail screen needs.
class SupervisorEmployeeDetail {
  final SupervisorEmployeeModel employee;
  final EditableContractModel editable;
  final List<Map<String, dynamic>> recentAttendance;

  const SupervisorEmployeeDetail({
    required this.employee,
    required this.editable,
    this.recentAttendance = const [],
  });

  factory SupervisorEmployeeDetail.fromJson(Map<String, dynamic> j) => SupervisorEmployeeDetail(
        employee: SupervisorEmployeeModel.fromJson(
            Map<String, dynamic>.from(j['employee'] as Map? ?? const {})),
        editable: EditableContractModel.fromJson(
            Map<String, dynamic>.from(j['editable'] as Map? ?? const {})),
        recentAttendance: ((j['recent_attendance'] as List?) ?? const [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
      );
}
