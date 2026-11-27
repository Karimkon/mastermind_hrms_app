import '../services/text_safe.dart';
class EmployeeModel {
  final int id;
  final String empNumber;
  final String fullName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? personalEmail;
  final String? phone;
  final String? department;
  final int? departmentId;
  final String? designation;
  final int? designationId;
  final String? hireDate;
  final String? employmentType;
  final String status;
  final String? avatarUrl;
  final String? clientName;
  final int? clientId;
  // Full detail fields
  final String? gender;
  final String? dateOfBirth;
  final String? address;
  final String? city;
  final String? country;
  final String? manager;
  final String? bio;

  /// The record exactly as the server sent it.
  ///
  /// The edit form covers the same forty-odd fields the browser form does,
  /// and gains one whenever that form does. Declaring each of them here three
  /// times over — field, constructor argument, fromJson line — is forty
  /// chances to mistype a key that Dart cannot check for us, because the names
  /// that matter are the server's, not Dart's. The form is a list of field
  /// descriptors keyed by those names and reads its values from here, so a
  /// field added on the server reaches the phone by adding one line to that
  /// list. The fields above stay as they are: the read-only screens use them.
  final Map<String, dynamic> raw;

  const EmployeeModel({
    required this.id,
    required this.empNumber,
    required this.fullName,
    this.firstName,
    this.lastName,
    this.email,
    this.personalEmail,
    this.phone,
    this.department,
    this.departmentId,
    this.designation,
    this.designationId,
    this.hireDate,
    this.employmentType,
    required this.status,
    this.avatarUrl,
    this.clientName,
    this.clientId,
    this.gender,
    this.dateOfBirth,
    this.address,
    this.city,
    this.country,
    this.manager,
    this.bio,
    this.raw = const {},
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> j) => EmployeeModel(
        id: j['id'],
        empNumber: j['emp_number'] ?? '',
        fullName: j['full_name'] ?? '',
        firstName: j['first_name'],
        lastName: j['last_name'],
        email: j['email'],
        personalEmail: j['personal_email'],
        phone: j['phone'],
        department: j['department'],
        departmentId: j['department_id'],
        designation: j['designation'],
        designationId: j['designation_id'],
        hireDate: j['hire_date'],
        employmentType: j['employment_type'],
        status: j['status'] ?? 'active',
        avatarUrl: j['avatar_url'],
        clientName: j['client_name'],
        clientId: j['client_id'],
        gender: j['gender'],
        dateOfBirth: j['date_of_birth'],
        address: j['address'],
        city: j['city'],
        country: j['country'],
        manager: j['manager'],
        bio: j['bio'],
        raw: j,
      );

  /// One field from the record, trimmed, with blank read as absent.
  ///
  /// Blank and absent have to mean the same thing to the form: the server
  /// sends null for a column never filled in and '' for one that was cleared,
  /// and an empty box is the right answer to both.
  String? text(String key) {
    final v = raw[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// A boolean the server may have sent as a bool, an int or a string.
  bool flag(String key) {
    final v = raw[key];
    return v == true || v == 1 || v == '1';
  }

  /// What the status dropdown should show: a hold is a flag beside the
  /// status column rather than a value in it, so it is read separately.
  String get state => text('state') ?? (flag('on_hold') ? 'on_hold' : status);

  /// Whether Save proposes this edit rather than writing it.
  bool get editsNeedApproval => flag('edits_need_approval');

  String get statusLabel {
    switch (status) {
      case 'on_leave': return 'On Leave';
      case 'terminated': return 'Terminated';
      case 'suspended': return 'Suspended';
      case 'active': return 'Active';
      default: return capitalise(status);
    }
  }
}
