class PayrollRunModel {
  final int id;
  final String title;
  final int month;
  final int year;
  final String status;
  final int employeeCount;
  final double totalGross;
  final double totalNet;
  final String createdAt;

  const PayrollRunModel({
    required this.id,
    required this.title,
    required this.month,
    required this.year,
    required this.status,
    required this.employeeCount,
    required this.totalGross,
    required this.totalNet,
    required this.createdAt,
  });

  factory PayrollRunModel.fromJson(Map<String, dynamic> j) => PayrollRunModel(
        id: j['id'],
        title: j['title'] ?? '',
        month: j['month'] ?? 0,
        year: j['year'] ?? 0,
        status: j['status'] ?? 'draft',
        employeeCount: j['employee_count'] ?? 0,
        totalGross: (j['total_gross'] ?? 0).toDouble(),
        totalNet: (j['total_net'] ?? 0).toDouble(),
        createdAt: j['created_at'] ?? '',
      );
}

class PayslipModel {
  final int id;
  final int? employeeId;
  final String? employee;
  final String? period;
  final int? month;
  final int? year;
  final double grossPay;
  final double netPay;
  final double basicSalary;
  final double tax;
  final double totalDeductions;
  final double totalAllowances;

  const PayslipModel({
    required this.id,
    this.employeeId,
    this.employee,
    this.period,
    this.month,
    this.year,
    required this.grossPay,
    required this.netPay,
    required this.basicSalary,
    required this.tax,
    required this.totalDeductions,
    required this.totalAllowances,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> j) => PayslipModel(
        id: j['id'],
        employeeId: j['employee_id'],
        employee: j['employee'],
        period: j['period'],
        month: j['month'],
        year: j['year'],
        grossPay: (j['gross_pay'] ?? 0).toDouble(),
        netPay: (j['net_pay'] ?? 0).toDouble(),
        basicSalary: (j['basic_salary'] ?? 0).toDouble(),
        tax: (j['tax'] ?? 0).toDouble(),
        totalDeductions: (j['total_deductions'] ?? 0).toDouble(),
        totalAllowances: (j['total_allowances'] ?? 0).toDouble(),
      );
}
