import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/attendance_model.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedStatus = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Stable query-string key so FutureProvider.family equality works correctly.
  String get _paramsKey {
    final parts = <String>[
      'month=${_selectedMonth.split('-')[1]}',
      'year=${_selectedMonth.split('-')[0]}',
    ];
    if (_selectedStatus != 'all') parts.add('status=$_selectedStatus');
    if (_searchCtrl.text.isNotEmpty) parts.add('search=${_searchCtrl.text}');
    return parts.join('&');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final todayAsync = ref.watch(attendanceTodayProvider);
    final listAsync = ref.watch(attendanceListProvider(_paramsKey));

    return Column(
      children: [
        // Today's status bar (for non-admin employees)
        if (!user.isAdmin)
          todayAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (state) => _TodayBar(state: state, ref: ref),
          ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FiltersRow(
                  searchCtrl: _searchCtrl,
                  selectedMonth: _selectedMonth,
                  selectedStatus: _selectedStatus,
                  onMonthChanged: (v) => setState(() => _selectedMonth = v),
                  onStatusChanged: (v) => setState(() => _selectedStatus = v),
                  onSearch: () => setState(() {}),
                ),
                const SizedBox(height: 20),
                listAsync.when(
                  loading: () => const Center(
                      child: Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator())),
                  error: (e, _) => _ErrorBanner(e.toString()),
                  data: (logs) =>
                      _AttendanceTable(logs: logs, isAdmin: user.isAdmin || user.isManager),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Today bar ────────────────────────────────────────────────────────────────

class _TodayBar extends StatelessWidget {
  final AttendanceTodayState state;
  final WidgetRef ref;
  const _TodayBar({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final today = state.log;
    final workSite = state.workSite;
    final isClockedIn = today?.isClockedIn ?? false;
    final isClockedOut = today?.isClockedOut ?? false;
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isClockedIn
                      ? AppColors.successLight
                      : isClockedOut
                          ? AppColors.infoLight
                          : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isClockedIn
                          ? Icons.circle
                          : isClockedOut
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                      size: 10,
                      color: isClockedIn
                          ? AppColors.success
                          : isClockedOut
                              ? AppColors.info
                              : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isClockedIn
                          ? 'Clocked In at ${today!.clockIn}'
                          : isClockedOut
                              ? 'Completed · ${today!.totalHours ?? '0'}h'
                              : 'Not Clocked In',
                      style: TextStyle(
                        color: isClockedIn
                            ? AppColors.success
                            : isClockedOut
                                ? AppColors.info
                                : AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text('Current time: $timeStr',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 16),
              if (!isClockedOut)
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      if (isClockedIn) {
                        await ref.read(attendanceTodayProvider.notifier).clockOut();
                      } else {
                        await ref.read(attendanceTodayProvider.notifier).clockIn();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(e.toString().replaceFirst('Exception: ', '')),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                  icon: Icon(
                      isClockedIn ? Icons.logout_rounded : Icons.login_rounded,
                      size: 16),
                  label: Text(isClockedIn ? 'Clock Out' : 'Clock In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isClockedIn ? AppColors.error : AppColors.success,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
            ],
          ),
          // Work site info (shown when employee has an assigned client)
          if (workSite != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                workSite['company_name'] as String? ?? 'Work Site',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              if (workSite['work_site_address'] != null) ...[
                const Text('  ·  ',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textMuted)),
                Expanded(
                    child: Text(
                  workSite['work_site_address'] as String,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                )),
              ],
              const SizedBox(width: 8),
              if (workSite['has_coordinates'] == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${workSite['geo_fence_radius']}m geo-fence',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text('No coordinates set',
                      style: TextStyle(fontSize: 11, color: AppColors.warning)),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─── Filters row ──────────────────────────────────────────────────────────────

class _FiltersRow extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String selectedMonth;
  final String selectedStatus;
  final ValueChanged<String> onMonthChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSearch;

  const _FiltersRow({
    required this.searchCtrl,
    required this.selectedMonth,
    required this.selectedStatus,
    required this.onMonthChanged,
    required this.onStatusChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) {
      final d = DateTime(DateTime.now().year, DateTime.now().month - i);
      return DateFormat('yyyy-MM').format(d);
    });

    return Row(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: searchCtrl,
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              hintText: 'Search employee...',
              prefixIcon:
                  Icon(Icons.search, size: 18, color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: selectedMonth,
          underline: const SizedBox(),
          items: months
              .map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(DateFormat('MMMM yyyy')
                      .format(DateTime.parse('$m-01')))))
              .toList(),
          onChanged: (v) { if (v != null) onMonthChanged(v); },
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: selectedStatus,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'present', child: Text('Present')),
            DropdownMenuItem(value: 'absent', child: Text('Absent')),
            DropdownMenuItem(value: 'late', child: Text('Late')),
            DropdownMenuItem(value: 'leave', child: Text('On Leave')),
          ],
          onChanged: (v) { if (v != null) onStatusChanged(v); },
        ),
      ],
    );
  }
}

// ─── Attendance table ─────────────────────────────────────────────────────────

class _AttendanceTable extends StatelessWidget {
  final List<AttendanceModel> logs;
  final bool isAdmin;
  const _AttendanceTable({required this.logs, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Column(
          children: [
            SizedBox(height: 60),
            Icon(Icons.fingerprint_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No attendance records found',
                style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                if (isAdmin)
                  const Expanded(
                      flex: 2,
                      child: Text('Employee',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.textSecondary))),
                const Expanded(
                    flex: 2,
                    child: Text('Date',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.textSecondary))),
                const Expanded(
                    child: Text('Clock In',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.textSecondary))),
                const Expanded(
                    child: Text('Clock Out',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.textSecondary))),
                const Expanded(
                    child: Text('Hours',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.textSecondary))),
                const Expanded(
                    child: Text('Status',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.textSecondary))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...logs.map((log) => _AttendanceRow(log: log, isAdmin: isAdmin)),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final AttendanceModel log;
  final bool isAdmin;
  const _AttendanceRow({required this.log, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (log.status) {
      'present' => AppColors.success,
      'absent' => AppColors.error,
      'late' => AppColors.warning,
      _ => AppColors.info,
    };
    final statusBg = switch (log.status) {
      'present' => AppColors.successLight,
      'absent' => AppColors.errorLight,
      'late' => AppColors.warningLight,
      _ => AppColors.infoLight,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: Row(
        children: [
          if (isAdmin)
            Expanded(
                flex: 2,
                child: Row(
                  children: [
                    CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.infoLight,
                        child: Text((log.employee ?? '?')[0],
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(log.employee ?? '-',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis)),
                  ],
                )),
          Expanded(
              flex: 2, child: Text(log.date, style: const TextStyle(fontSize: 13))),
          Expanded(
              child: Text(log.clockIn ?? '-', style: const TextStyle(fontSize: 13))),
          Expanded(
              child: Text(log.clockOut ?? '-',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
              child: Text(log.totalHours ?? '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration:
                  BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
              child: Text(
                log.status[0].toUpperCase() + log.status.substring(1),
                style: TextStyle(
                    color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
