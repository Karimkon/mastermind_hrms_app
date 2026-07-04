class UserModel {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String status;
  final bool mfaEnabled;
  final List<String> roles;
  final List<String> permissions;
  final EmployeeInfo? employee;
  final ClientInfo? client;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.status,
    required this.mfaEnabled,
    required this.roles,
    required this.permissions,
    this.employee,
    this.client,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        avatarUrl: j['avatar_url'],
        status: j['status'] ?? 'active',
        mfaEnabled: j['mfa_enabled'] ?? false,
        roles: List<String>.from(j['roles'] ?? []),
        permissions: List<String>.from(j['permissions'] ?? []),
        employee: j['employee'] != null ? EmployeeInfo.fromJson(j['employee']) : null,
        client: j['client'] != null ? ClientInfo.fromJson(j['client']) : null,
      );

  bool hasRole(String role) => roles.contains(role);
  bool hasAnyRole(List<String> r) => r.any(roles.contains);

  bool get isAdmin          => hasAnyRole(['super-admin', 'hr-admin']);
  bool get isManager        => hasRole('manager');
  bool get isEmployee       => hasRole('employee');
  bool get isClient         => hasRole('client');
  bool get isPayroll        => hasRole('payroll-officer');
  bool get isRecruiter      => hasRole('recruiter');
  bool get isAccountManager => hasRole('account-manager');
  bool get canSeeBsc        => isAdmin || isManager || isAccountManager || isEmployee;
  bool get canSeeProbation  => isAdmin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar_url': avatarUrl,
        'status': status,
        'mfa_enabled': mfaEnabled,
        'roles': roles,
        'permissions': permissions,
        'employee': employee?.toJson(),
        'client': client?.toJson(),
      };
}

class EmployeeInfo {
  final int id;
  final String empNumber;
  final String fullName;
  final String? department;
  final String? designation;

  const EmployeeInfo({
    required this.id,
    required this.empNumber,
    required this.fullName,
    this.department,
    this.designation,
  });

  factory EmployeeInfo.fromJson(Map<String, dynamic> j) => EmployeeInfo(
        id: j['id'],
        empNumber: j['emp_number'] ?? '',
        fullName: j['full_name'] ?? '',
        department: j['department'],
        designation: j['designation'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'emp_number': empNumber,
        'full_name': fullName,
        'department': department,
        'designation': designation,
      };
}

class ClientInfo {
  final int id;
  final String companyName;
  final String? contactPerson;

  const ClientInfo({
    required this.id,
    required this.companyName,
    this.contactPerson,
  });

  factory ClientInfo.fromJson(Map<String, dynamic> j) => ClientInfo(
        id: j['id'],
        companyName: j['company_name'] ?? '',
        contactPerson: j['contact_person'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_name': companyName,
        'contact_person': contactPerson,
      };
}
