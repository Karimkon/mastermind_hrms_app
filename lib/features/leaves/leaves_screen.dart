import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/leave_provider.dart';
import '../../core/models/leave_model.dart';

class LeavesScreen extends ConsumerStatefulWidget {
  const LeavesScreen({super.key});

  @override
  ConsumerState<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends ConsumerState<LeavesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _paramsKey => _statusFilter == 'all' ? '' : 'status=$_statusFilter';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final balanceAsync = ref.watch(leaveBalanceProvider);
    final requestsAsync = ref.watch(leaveListProvider(_paramsKey));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leave Balance cards (for employees)
          if (!user.isAdmin || user.isEmployee) ...[
            balanceAsync.when(
              loading: () => Shimmer.fromColors(
                baseColor: const Color(0xFFE2E8F0),
                highlightColor: const Color(0xFFF8FAFC),
                child: Row(children: List.generate(3, (i) => Expanded(child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 16 : 0),
                  child: Container(height: 88, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                )))),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (balances) => _LeaveBalanceCards(balances: balances),
            ),
            const SizedBox(height: 24),
          ],

          // Header row
          Row(
            children: [
              const Text('Leave Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              // Status filter
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showApplyDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Apply for Leave'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Leave requests table
          requestsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => _ErrorCard(e.toString()),
            data: (requests) => _LeaveRequestsTable(
              requests: requests,
              isAdmin: user.isAdmin || user.isManager,
              onApprove: (id) => _doApprove(id),
              onReject: (id) => _showRejectDialog(context, id),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doApprove(int id) async {
    final ok = await ref.read(leaveActionsProvider.notifier).approveLeave(id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave approved'), backgroundColor: AppColors.success));
      ref.invalidate(leaveListProvider);
    }
  }

  Future<void> _showRejectDialog(BuildContext context, int id) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Rejection reason...')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await ref.read(leaveActionsProvider.notifier).rejectLeave(id, ctrl.text);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave rejected'), backgroundColor: AppColors.error));
        ref.invalidate(leaveListProvider);
      }
    }
  }

  Future<void> _showApplyDialog(BuildContext context) async {
    final typesAsync = ref.read(leaveTypesProvider);
    final types = typesAsync.valueOrNull ?? [];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _ApplyLeaveDialog(types: types),
    );
  }
}

class _LeaveBalanceCards extends StatelessWidget {
  final List<LeaveBalanceModel> balances;
  const _LeaveBalanceCards({required this.balances});

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) return const SizedBox.shrink();
    return Row(
      children: balances.map((b) {
        final pct = b.total > 0 ? b.used / b.total : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: b.color != null ? _hexColor(b.color!) : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(b.type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      Text('${b.remaining} left', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.surface,
                      color: b.color != null ? _hexColor(b.color!) : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${b.used} used · ${b.pending} pending · ${b.total} total',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _LeaveRequestsTable extends StatelessWidget {
  final List<LeaveRequestModel> requests;
  final bool isAdmin;
  final Function(int) onApprove;
  final Function(int) onReject;

  const _LeaveRequestsTable({
    required this.requests,
    required this.isAdmin,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(60),
          child: Column(
            children: const [
              Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text('No leave requests found', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
            ],
          ),
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
          _TableHeader(isAdmin: isAdmin),
          ...requests.map((r) => _LeaveRow(request: r, isAdmin: isAdmin, onApprove: onApprove, onReject: onReject)),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final bool isAdmin;
  const _TableHeader({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Row(
        children: [
          if (isAdmin) const Expanded(flex: 2, child: _ColHead('Employee')),
          const Expanded(flex: 2, child: _ColHead('Leave Type')),
          const Expanded(flex: 2, child: _ColHead('Duration')),
          const Expanded(child: _ColHead('Days')),
          const Expanded(child: _ColHead('Status')),
          if (isAdmin) const Expanded(child: _ColHead('Actions')),
        ],
      ),
    );
  }
}

class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary));
  }
}

class _LeaveRow extends StatelessWidget {
  final LeaveRequestModel request;
  final bool isAdmin;
  final Function(int) onApprove;
  final Function(int) onReject;

  const _LeaveRow({required this.request, required this.isAdmin, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusFg) = switch (request.status.toLowerCase()) {
      'approved' => (AppColors.successLight, AppColors.success),
      'rejected' => (AppColors.errorLight, AppColors.error),
      'pending' => (AppColors.warningLight, AppColors.warning),
      _ => (AppColors.infoLight, AppColors.info),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: Row(
        children: [
          if (isAdmin) Expanded(flex: 2, child: Row(children: [
            CircleAvatar(radius: 14, backgroundColor: AppColors.infoLight, child: Text((request.employee ?? '?')[0], style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Expanded(child: Text(request.employee ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(
              color: request.leaveTypeColor != null ? _hex(request.leaveTypeColor!) : AppColors.primary,
              shape: BoxShape.circle,
            )),
            const SizedBox(width: 8),
            Expanded(child: Text(request.leaveType, style: const TextStyle(fontSize: 13))),
          ])),
          Expanded(flex: 2, child: Text('${request.startDate} → ${request.endDate}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text('${request.days} day${request.days == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              request.status[0].toUpperCase() + request.status.substring(1),
              style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          )),
          if (isAdmin && request.status == 'pending')
            Expanded(child: Row(children: [
              IconButton(
                onPressed: () => onApprove(request.id),
                icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                tooltip: 'Approve',
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: () => onReject(request.id),
                icon: const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                tooltip: 'Reject',
                padding: EdgeInsets.zero,
              ),
            ]))
          else if (isAdmin)
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Color _hex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _ApplyLeaveDialog extends ConsumerStatefulWidget {
  final List<LeaveTypeModel> types;
  const _ApplyLeaveDialog({required this.types});

  @override
  ConsumerState<_ApplyLeaveDialog> createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends ConsumerState<_ApplyLeaveDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedTypeId;
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedTypeId,
                decoration: const InputDecoration(labelText: 'Leave Type'),
                items: widget.types.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _selectedTypeId = v),
                validator: (v) => v == null ? 'Select leave type' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _fromDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'From Date'),
                        child: Text(_fromDate != null ? '${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}' : 'Select date'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fromDate ?? DateTime.now(),
                          firstDate: _fromDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _toDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'To Date'),
                        child: Text(_toDate != null ? '${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}' : 'Select date'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reason (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates')));
      return;
    }
    setState(() => _loading = true);
    final ok = await ref.read(leaveActionsProvider.notifier).applyLeave({
      'leave_type_id': _selectedTypeId,
      'from_date': '${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}',
      'to_date': '${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}',
      'reason': _reasonCtrl.text,
    });
    if (!mounted) return;
    if (ok) {
      // Show snackbar before popping so context is still valid
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request submitted'), backgroundColor: AppColors.success));
      ref.invalidate(leaveListProvider);
      ref.invalidate(leaveBalanceProvider);
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit leave request'), backgroundColor: AppColors.error));
      return;
    }
    Navigator.pop(context);
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
