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
      );

  String get statusLabel {
    switch (status) {
      case 'on_leave': return 'On Leave';
      case 'terminated': return 'Terminated';
      case 'suspended': return 'Suspended';
      case 'active': return 'Active';
      default: return status[0].toUpperCase() + status.substring(1);
    }
  }
}
