import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';

class AmPayrollScreen extends ConsumerStatefulWidget {
  const AmPayrollScreen({super.key});

  @override
  ConsumerState<AmPayrollScreen> createState() => _AmPayrollScreenState();
}

class _AmPayrollScreenState extends ConsumerState<AmPayrollScreen> {
  List<Map<String, dynamic>> _runs = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;
  int? _selectedClientId;
  final _fmt = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadClients();
    _load();
  }

  Future<void> _loadClients() async {
    try {
      final resp = await ApiService.get(ApiConstants.amClients);
      if (mounted) {
        setState(() {
          _clients = (resp.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{
        if (_selectedClientId != null) 'client_id': _selectedClientId,
      };
      final resp = await ApiService.get(ApiConstants.amPayroll, params: params);
      final d = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _runs = (d['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _showPayslips(Map<String, dynamic> run) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayslipsSheet(run: run, fmt: _fmt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_clients.isNotEmpty) SliverToBoxAdapter(child: _buildClientFilter()),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else if (_runs.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else ...[
              SliverToBoxAdapter(child: _buildSummaryCards()),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _RunCard(run: _runs[i], fmt: _fmt, onTap: () => _showPayslips(_runs[i])),
                    childCount: _runs.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payroll', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text('Payroll runs for your managed employees', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildClientFilter() {
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: 'All Companies',
              selected: _selectedClientId == null,
              onTap: () { setState(() => _selectedClientId = null); _load(); },
            ),
            ..._clients.map((c) => _Chip(
              label: c['company_name'] ?? '',
              selected: _selectedClientId == c['id'],
              onTap: () { setState(() => _selectedClientId = c['id'] as int?); _load(); },
              color: AppColors.primary,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalGross = _runs.fold<double>(0, (s, r) => s + ((r['total_gross'] as num?)?.toDouble() ?? 0));
    final totalNet   = _runs.fold<double>(0, (s, r) => s + ((r['total_net']   as num?)?.toDouble() ?? 0));
    final totalEmps  = _runs.fold<int>(0, (s, r) => s + ((r['employee_count'] as int?) ?? 0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          _SummaryCard(label: 'Runs', value: '${_runs.length}', color: AppColors.primary),
          const SizedBox(width: 10),
          _SummaryCard(label: 'Employees', value: '$totalEmps', color: AppColors.textSecondary),
          const SizedBox(width: 10),
          _SummaryCard(label: 'Total Net', value: 'UGX ${_fmt.format(totalNet)}', color: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─── Payroll Run Card ─────────────────────────────────────────────────────────

class _RunCard extends StatelessWidget {
  final Map<String, dynamic> run;
  final NumberFormat fmt;
  final VoidCallback onTap;
  const _RunCard({required this.run, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLocked = run['is_locked'] == true;
    final status   = run['status'] ?? 'draft';
    final empCount = run['employee_count'] ?? 0;
    final gross    = (run['total_gross'] as num?)?.toDouble() ?? 0;
    final net      = (run['total_net']   as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: empCount > 0 ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isLocked ? AppColors.errorLight : AppColors.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(run['title'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                        if ((run['client_name'] ?? '').toString().isNotEmpty && run['client_name'] != '—')
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.location_city_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text(run['client_name'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 11, color: AppColors.error),
                          SizedBox(width: 3),
                          Text('Locked', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                        ],
                      ),
                    )
                  else
                    _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _PayItem(label: 'Employees', value: '$empCount')),
                  Expanded(child: _PayItem(label: 'Gross (UGX)', value: fmt.format(gross))),
                  Expanded(child: _PayItem(label: 'Net (UGX)', value: fmt.format(net), highlight: true)),
                ],
              ),
              if ((run['payment_date'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('Payment date: ${run['payment_date']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
              if (empCount > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('View payslips', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Payslips Bottom Sheet ────────────────────────────────────────────────────

class _PayslipsSheet extends StatefulWidget {
  final Map<String, dynamic> run;
  final NumberFormat fmt;
  const _PayslipsSheet({required this.run, required this.fmt});

  @override
  State<_PayslipsSheet> createState() => _PayslipsSheetState();
}

class _PayslipsSheetState extends State<_PayslipsSheet> {
  List<Map<String, dynamic>> _payslips = [];
  Map<String, dynamic>? _totals;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final runId = widget.run['id'];
      final resp = await ApiService.get('${ApiConstants.amPayroll}/$runId/payslips');
      final d = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _payslips = (d['payslips'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _totals   = d['totals'] != null ? Map<String, dynamic>.from(d['totals'] as Map) : null;
          _loading  = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.85;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inputBorder, borderRadius: BorderRadius.circular(2)))),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.run['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      Text(widget.run['client_name'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                    : _payslips.isEmpty
                        ? const Center(child: Text('No payslips found', style: TextStyle(color: AppColors.textMuted)))
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (_totals != null) _buildTotalsCard(),
                              const SizedBox(height: 12),
                              ..._payslips.map((p) => _PayslipCard(payslip: p, fmt: widget.fmt)),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    final gross = (_totals!['gross'] as num?)?.toDouble() ?? 0;
    final net   = (_totals!['net']   as num?)?.toDouble() ?? 0;
    final tax   = (_totals!['tax']   as num?)?.toDouble() ?? 0;
    final count = _totals!['count']  ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1e3a8a), AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _TotalItem(label: 'Employees', value: '$count', light: true)),
          Expanded(child: _TotalItem(label: 'Gross', value: widget.fmt.format(gross), light: true)),
          Expanded(child: _TotalItem(label: 'Tax', value: widget.fmt.format(tax), light: true)),
          Expanded(child: _TotalItem(label: 'Net Pay', value: widget.fmt.format(net), light: true, bold: true)),
        ],
      ),
    );
  }
}

class _TotalItem extends StatelessWidget {
  final String label, value;
  final bool light, bold;
  const _TotalItem({required this.label, required this.value, this.light = false, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: light ? Colors.white70 : AppColors.textMuted)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: light ? Colors.white : AppColors.textPrimary)),
      ],
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final Map<String, dynamic> payslip;
  final NumberFormat fmt;
  const _PayslipCard({required this.payslip, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payslip['employee'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                    Text(payslip['department'] ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Text('UGX ${fmt.format((payslip['net_salary'] as num?)?.toDouble() ?? 0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _PayItem(label: 'Basic', value: fmt.format((payslip['basic_salary'] as num?)?.toDouble() ?? 0))),
              Expanded(child: _PayItem(label: 'Gross', value: fmt.format((payslip['gross_salary'] as num?)?.toDouble() ?? 0))),
              Expanded(child: _PayItem(label: 'PAYE', value: fmt.format((payslip['tax_amount'] as num?)?.toDouble() ?? 0))),
              Expanded(child: _PayItem(label: 'Deductions', value: fmt.format((payslip['total_deductions'] as num?)?.toDouble() ?? 0))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _PayItem extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _PayItem({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: highlight ? AppColors.success : AppColors.textPrimary)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label;
    switch (status) {
      case 'approved': bg = AppColors.successLight; fg = AppColors.success;  label = 'Approved'; break;
      case 'paid':     bg = AppColors.successLight; fg = AppColors.success;  label = 'Paid';     break;
      case 'processed':bg = AppColors.infoLight;    fg = AppColors.primary;  label = 'Processed';break;
      case 'draft':    bg = AppColors.cardBorder;   fg = AppColors.textMuted; label = 'Draft';   break;
      default:         bg = AppColors.warningLight; fg = AppColors.warning;  label = status;     break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _Chip({required this.label, required this.selected, required this.onTap, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.inputBorder, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? color : AppColors.textSecondary)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('No payroll runs yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          SizedBox(height: 4),
          Text('Payroll is processed by HR Admin.\nCheck back after your client\'s payment date.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
