import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';

final _reportProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, endpoint) async {
  try {
    final res = await ApiService.get(endpoint);
    return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
  } catch (_) {
    return {};
  }
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reports & Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth < 600 ? 1 : constraints.maxWidth < 900 ? 2 : 3;
            return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: cols == 1 ? 2.2 : 1.5,
            children: [
              _ReportCard(
                icon: Icons.fingerprint_rounded,
                title: 'Attendance Report',
                description: 'Monthly attendance summary with present, absent, and late counts',
                color: AppColors.primary,
                bg: AppColors.infoLight,
                endpoint: ApiConstants.reportsAttendance,
                buildSummary: _attendanceSummary,
              ),
              _ReportCard(
                icon: Icons.beach_access_rounded,
                title: 'Leave Report',
                description: 'Leave usage, balances, and pending requests by department',
                color: AppColors.success,
                bg: AppColors.successLight,
                endpoint: ApiConstants.reportsLeave,
                buildSummary: _leaveSummary,
              ),
              _ReportCard(
                icon: Icons.payments_rounded,
                title: 'Payroll Report',
                description: 'Monthly payroll summary with gross, deductions, and net pay',
                color: const Color(0xFF8B5CF6),
                bg: const Color(0xFFF5F3FF),
                endpoint: ApiConstants.reportsPayroll,
                buildSummary: _payrollSummary,
              ),
              _ReportCard(
                icon: Icons.people_rounded,
                title: 'Employee Report',
                description: 'Employee demographics, department breakdown, and tenure analysis',
                color: AppColors.warning,
                bg: AppColors.warningLight,
                endpoint: ApiConstants.reportsEmployees,
                buildSummary: _employeeSummary,
              ),
              _ReportCard(
                icon: Icons.bar_chart_rounded,
                title: 'Performance Report',
                description: 'KPI scores, goal completion rates, and review ratings',
                color: const Color(0xFF0EA5E9),
                bg: const Color(0xFFE0F2FE),
                endpoint: ApiConstants.reportsPerformance,
                buildSummary: _performanceSummary,
              ),
              _ReportCard(
                icon: Icons.school_rounded,
                title: 'Training Report',
                description: 'Course enrollments, completion rates, and certifications',
                color: const Color(0xFFEC4899),
                bg: const Color(0xFFFDF2F8),
                endpoint: ApiConstants.reportsTraining,
                buildSummary: _trainingSummary,
              ),
            ],
          );
          }),
        ],
      ),
    );
  }

  static List<_Stat> _attendanceSummary(Map<String, dynamic> d) => [
    _Stat('Present', '${d['present_count'] ?? d['total_present'] ?? '-'}'),
    _Stat('Absent',  '${d['absent_count']  ?? d['total_absent']  ?? '-'}'),
    _Stat('Late',    '${d['late_count']    ?? d['total_late']    ?? '-'}'),
  ];

  static List<_Stat> _leaveSummary(Map<String, dynamic> d) => [
    _Stat('Pending',  '${d['pending_count']  ?? '-'}'),
    _Stat('Approved', '${d['approved_count'] ?? '-'}'),
    _Stat('Rejected', '${d['rejected_count'] ?? '-'}'),
  ];

  static List<_Stat> _payrollSummary(Map<String, dynamic> d) {
    final fmt = NumberFormat('#,##0', 'en');
    return [
      _Stat('Employees', '${d['employee_count'] ?? '-'}'),
      _Stat('Gross', 'UGX ${fmt.format((d['total_gross'] as num?)?.toDouble() ?? 0)}'),
      _Stat('Net',   'UGX ${fmt.format((d['total_net']   as num?)?.toDouble() ?? 0)}'),
    ];
  }

  static List<_Stat> _employeeSummary(Map<String, dynamic> d) => [
    _Stat('Total',   '${d['total']   ?? d['total_employees'] ?? '-'}'),
    _Stat('Active',  '${d['active']  ?? d['active_count']    ?? '-'}'),
    _Stat('Depts',   '${d['departments_count'] ?? '-'}'),
  ];

  static List<_Stat> _performanceSummary(Map<String, dynamic> d) => [
    _Stat('Reviews', '${d['reviews_count'] ?? '-'}'),
    _Stat('Avg Score', '${d['average_score'] ?? '-'}'),
    _Stat('Goals Done', '${d['goals_completed'] ?? '-'}'),
  ];

  static List<_Stat> _trainingSummary(Map<String, dynamic> d) => [
    _Stat('Courses',    '${d['total_courses'] ?? '-'}'),
    _Stat('Enrolled',   '${d['total_enrollments'] ?? '-'}'),
    _Stat('Completion', '${d['completion_rate'] ?? '-'}%'),
  ];
}

class _Stat {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
}

class _ReportCard extends ConsumerStatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color bg;
  final String endpoint;
  final List<_Stat> Function(Map<String, dynamic>) buildSummary;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.bg,
    required this.endpoint,
    required this.buildSummary,
  });

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_reportProvider(widget.endpoint));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_)  => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showDetailSheet(context, dataAsync),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? widget.color : AppColors.cardBorder),
            boxShadow: _hovered
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const Spacer(),
                  dataAsync.when(
                    loading: () => const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    data: (_) => Icon(Icons.open_in_new_rounded,
                        color: _hovered ? widget.color : AppColors.textMuted, size: 18),
                  ),
                ],
              ),
              const Spacer(),
              Text(widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text(widget.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              // Live mini-stats
              dataAsync.maybeWhen(
                data: (d) {
                  if (d.isEmpty) return const SizedBox.shrink();
                  final stats = widget.buildSummary(d);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: stats.take(3).map((s) => Expanded(
                        child: Column(
                          children: [
                            Text(s.value,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.color),
                                overflow: TextOverflow.ellipsis),
                            Text(s.label,
                                style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                          ],
                        ),
                      )).toList(),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, AsyncValue<Map<String, dynamic>> dataAsync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(8)),
                    child: Icon(widget.icon, color: widget.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: dataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (d) {
                  if (d.isEmpty) {
                    return const Center(child: Text('No data available',
                        style: TextStyle(color: AppColors.textMuted)));
                  }
                  final stats = widget.buildSummary(d);
                  return ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Stat row
                      Row(
                        children: stats.map((s) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: widget.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(s.value, style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900, color: widget.color)),
                                const SizedBox(height: 4),
                                Text(s.label, style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Raw data rows
                      ...d.entries.where((e) => e.value is! Map && e.value is! List).map((e) =>
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(
                                e.key.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600),
                              )),
                              Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
