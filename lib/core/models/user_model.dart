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

  bool can(String permission) => permissions.contains(permission);
  bool canAny(List<String> p) => p.any(permissions.contains);

  /// May this person reach a module — by role, or by a permission that says
  /// the same thing?
  ///
  /// The same rule as App\Support\Nav on the server, and for the same reason.
  /// The menu was gated on role names alone, so somebody granted a permission
  /// saw no change: the screen they had just been given was behind a block
  /// their role did not open. `permissions` has always been in the sign-in
  /// response and nothing read it.
  ///
  /// [deny] is for a role that holds the permission for its OWN scoped screen
  /// and must not be given the company-wide one — an account manager holds
  /// employees.view for their client list, which is not Employee Central.
  bool mayOpen({
    List<String> roles = const [],
    List<String> perms = const [],
    List<String> deny = const [],
  }) {
    if (deny.isNotEmpty && hasAnyRole(deny)) return false;

    return hasAnyRole(roles) || (perms.isNotEmpty && canAny(perms));
  }

  bool get isAdmin          => hasAnyRole(['super-admin', 'hr-admin']);
  bool get isManager        => hasRole('manager');
  bool get isEmployee       => hasRole('employee');
  bool get isClient         => hasRole('client');
  bool get isPayroll        => hasRole('payroll-officer');
  bool get isRecruiter      => hasRole('recruiter');
  bool get isAccountManager => hasRole('account-manager');

  /// Posted to a client site to watch the workforce placed there.
  ///
  /// The role grants the menu; a dated posting grants the site. Somebody
  /// holding this role with no current posting sees the screens and is
  /// told they have no posting, which is the honest answer - an empty
  /// list would read as "nobody is here today".
  bool get isFieldSupervisor => hasRole('field-supervisor');
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
