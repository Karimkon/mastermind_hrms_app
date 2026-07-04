import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';

class AmSalaryPaymentsScreen extends ConsumerStatefulWidget {
  const AmSalaryPaymentsScreen({super.key});

  @override
  ConsumerState<AmSalaryPaymentsScreen> createState() => _AmSalaryPaymentsScreenState();
}

class _AmSalaryPaymentsScreenState extends ConsumerState<AmSalaryPaymentsScreen> {
  List<Map<String, dynamic>> _payments  = [];
  List<Map<String, dynamic>> _clients   = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;
  int? _filterClientId;
  int? _filterMonth;

  final _fmt = NumberFormat('#,##0', 'en');
  final _monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{};
      if (_filterClientId != null) params['client_id'] = _filterClientId;
      if (_filterMonth != null)    params['month']     = _filterMonth;

      final paymentsResp  = await ApiService.get(ApiConstants.amSalaryPayments, params: params);
      final clientsResp   = await ApiService.get(ApiConstants.amClients);
      final employeesResp = await ApiService.get(ApiConstants.amEmployees, params: {'per_page': '200'});

      if (!mounted) return;
      setState(() {
        _loading  = false;
        final d   = paymentsResp.data as Map<String, dynamic>? ?? {};
        _payments = List<Map<String, dynamic>>.from(d['data'] ?? []);
        _clients  = (clientsResp.data is List)
            ? List<Map<String, dynamic>>.from(clientsResp.data)
            : [];
        final ed  = employeesResp.data as Map<String, dynamic>? ?? {};
        _employees= List<Map<String, dynamic>>.from(ed['data'] ?? []);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<bool> _savePayment(Map<String, dynamic> data) async {
    try {
      await ApiService.post(ApiConstants.amSalaryPayments, data: data);
      await _loadAll();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
      return false;
    }
  }

  Future<void> _deletePayment(int id) async {
    try {
      await ApiService.delete('${ApiConstants.amSalaryPayments}/$id');
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  double get _totalGross => _payments.fold(0, (a, p) => a + ((p['gross_salary'] as num?)?.toDouble() ?? 0));
  double get _totalDed   => _payments.fold(0, (a, p) => a + ((p['total_deductions'] as num?)?.toDouble() ?? 0));
  double get _totalNet   => _payments.fold(0, (a, p) => a + ((p['net_salary'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildFilters()),
                      SliverToBoxAdapter(child: _buildSummary()),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (_payments.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.payments_outlined, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                const Text('No salary payments recorded yet.', style: TextStyle(color: AppColors.textMuted)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _showForm(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Record First Payment'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _PaymentCard(
                                payment: _payments[i],
                                fmt: _fmt,
                                onDelete: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete Payment'),
                                      content: const Text('Delete this salary payment record? This cannot be undone.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) _deletePayment(_payments[i]['id']);
                                },
                              ),
                              childCount: _payments.length,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(child: _dropFilter<int>(
            hint: 'All Clients',
            value: _filterClientId,
            items: _clients.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['company_name'] ?? '', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) { setState(() => _filterClientId = v); _loadAll(); },
          )),
          const SizedBox(width: 8),
          Expanded(child: _dropFilter<int>(
            hint: 'All Months',
            value: _filterMonth,
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i]))),
            onChanged: (v) { setState(() => _filterMonth = v); _loadAll(); },
          )),
          if (_filterClientId != null || _filterMonth != null)
            IconButton(
              onPressed: () { setState(() { _filterClientId = null; _filterMonth = null; }); _loadAll(); },
              icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _sumCard('Gross',      'UGX ${_fmt.format(_totalGross)}', AppColors.primary),
        const SizedBox(width: 8),
        _sumCard('Deductions', 'UGX ${_fmt.format(_totalDed)}',   AppColors.error),
        const SizedBox(width: 8),
        _sumCard('Net Pay',    'UGX ${_fmt.format(_totalNet)}',   AppColors.success),
      ]),
    );
  }

  Widget _sumCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    ),
  );

  Widget _dropFilter<T>({required String hint, required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          isExpanded: true,
          items: [DropdownMenuItem<T>(value: null, child: Text(hint, style: const TextStyle(fontSize: 13))), ...items],
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  void _showForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentFormSheet(
        clients:   _clients,
        employees: _employees,
        onSave:    _savePayment,
      ),
    );
  }
}

// ─── Payment Card ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final NumberFormat fmt;
  final VoidCallback onDelete;
  const _PaymentCard({required this.payment, required this.fmt, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final net   = (payment['net_salary']       as num?)?.toDouble() ?? 0;
    final gross = (payment['gross_salary']      as num?)?.toDouble() ?? 0;
    final basic = (payment['basic_salary']      as num?)?.toDouble() ?? 0;
    final allow = (payment['allowances']        as num?)?.toDouble() ?? 0;
    final paye  = (payment['paye_tax']          as num?)?.toDouble() ?? 0;
    final nssf  = (payment['nssf']              as num?)?.toDouble() ?? 0;
    final other = (payment['other_deductions']  as num?)?.toDouble() ?? 0;
    final ded   = (payment['total_deductions']  as num?)?.toDouble() ?? 0;
    final method = (payment['payment_method'] as String? ?? '').replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.infoLight,
                  child: Text(((payment['employee_name'] as String?) ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payment['employee_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${payment['emp_number'] ?? ''} · ${payment['department'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(20)),
                      child: Text(payment['period_label'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                    if (method.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(method, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Breakdown
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _row('Gross Salary',      basic, fmt, AppColors.textSecondary),
                if (allow > 0) _row('Add. Allowances', allow, fmt, AppColors.success),
                _row('Total Earnings',    gross, fmt, AppColors.textPrimary, bold: true),
                if (paye  > 0) _row('PAYE Tax',         paye,  fmt, AppColors.warning,  prefix: '−'),
                if (nssf  > 0) _row('NSSF',             nssf,  fmt, AppColors.warning,  prefix: '−'),
                if (other > 0) _row('Other Deductions', other, fmt, AppColors.error,    prefix: '−'),
                if (ded   > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: _row('Total Deductions', ded, fmt, AppColors.error, bold: true, prefix: '−'),
                  ),
                const Divider(height: 12),
                Row(
                  children: [
                    const Text('NET PAY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const Spacer(),
                    Text('UGX ${fmt.format(net)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.success)),
                  ],
                ),
              ],
            ),
          ),

          // Footer
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  payment['payment_date'] != null
                      ? 'Paid: ${DateFormat('dd MMM yyyy').format(DateTime.parse(payment['payment_date']))}'
                      : 'No date set',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const Spacer(),
                if ((payment['payment_reference'] as String? ?? '').isNotEmpty)
                  Text('Ref: ${payment['payment_reference']}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 12),
                GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double val, NumberFormat fmt, Color color, {bool bold = false, String prefix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: bold ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          const Spacer(),
          Text('$prefix UGX ${fmt.format(val)}', style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ─── Payment Form Sheet ────────────────────────────────────────────────────────

class _PaymentFormSheet extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> employees;
  final Future<bool> Function(Map<String, dynamic>) onSave;
  const _PaymentFormSheet({required this.clients, required this.employees, required this.onSave});

  @override
  State<_PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends State<_PaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _empId;
  int? _clientId;
  int  _month = DateTime.now().month;
  int  _year  = DateTime.now().year;
  final _basic  = TextEditingController();
  final _allow  = TextEditingController(text: '0');
  final _paye   = TextEditingController(text: '0');
  final _nssf   = TextEditingController(text: '0');
  final _other  = TextEditingController(text: '0');
  final _ref    = TextEditingController();
  String? _method;
  DateTime _payDate = DateTime.now();
  bool _saving = false;

  final _fmt = NumberFormat('#,##0', 'en');
  final _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  double get _gross => (double.tryParse(_basic.text) ?? 0) + (double.tryParse(_allow.text) ?? 0);
  double get _totalDed => (double.tryParse(_paye.text) ?? 0) + (double.tryParse(_nssf.text) ?? 0) + (double.tryParse(_other.text) ?? 0);
  double get _net => _gross - _totalDed;

  @override
  void dispose() {
    _basic.dispose(); _allow.dispose(); _paye.dispose();
    _nssf.dispose(); _other.dispose(); _ref.dispose();
    super.dispose();
  }

  InputDecoration _dec({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true, fillColor: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Text('Record Salary Payment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              child: Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Employee
                    _label('Employee *'),
                    DropdownButtonFormField<int>(
                      value: _empId,
                      hint: const Text('Select Employee'),
                      decoration: _dec(),
                      items: widget.employees.map((e) => DropdownMenuItem(
                        value: e['id'] as int,
                        child: Text('${e['full_name']} (${e['emp_number'] ?? ''})', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _empId = v);
                        if (v != null) {
                          final emp = widget.employees.firstWhere((e) => e['id'] == v, orElse: () => {});
                          final salary = (emp['basic_salary'] as num?)?.toDouble() ?? 0;
                          if (salary > 0) _basic.text = salary.toStringAsFixed(0);
                        }
                      },
                      validator: (v) => v == null ? 'Select an employee' : null,
                    ),
                    const SizedBox(height: 12),

                    // Client
                    _label('Client *'),
                    DropdownButtonFormField<int>(
                      value: _clientId,
                      hint: const Text('Select Client'),
                      decoration: _dec(),
                      items: widget.clients.map((c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['company_name'] ?? ''),
                      )).toList(),
                      onChanged: (v) => setState(() => _clientId = v),
                      validator: (v) => v == null ? 'Select a client' : null,
                    ),
                    const SizedBox(height: 12),

                    // Period
                    _label('Pay Period *'),
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<int>(
                        value: _month,
                        decoration: _dec(),
                        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i]))),
                        onChanged: (v) => setState(() => _month = v!),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: DropdownButtonFormField<int>(
                        value: _year,
                        decoration: _dec(),
                        items: List.generate(6, (i) => DateTime.now().year - i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (v) => setState(() => _year = v!),
                      )),
                    ]),

                    const SizedBox(height: 20),
                    _section('Earnings', Icons.add_circle_outline_rounded, AppColors.success),
                    const SizedBox(height: 10),

                    _label('Gross Salary (UGX) *'),
                    TextFormField(
                      controller: _basic,
                      decoration: _dec(hint: 'Auto-filled from employee record'),
                      keyboardType: TextInputType.number,
                      validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a valid amount' : null,
                    ),
                    const SizedBox(height: 10),

                    _label('Additional Allowances (UGX)'),
                    TextFormField(controller: _allow, decoration: _dec(hint: 'Bonus, overtime, etc. (0 if none)'), keyboardType: TextInputType.number),

                    const SizedBox(height: 8),
                    _totalBox('Total Earnings', _gross, AppColors.primary),

                    const SizedBox(height: 20),
                    _section('Deductions', Icons.remove_circle_outline_rounded, AppColors.error),
                    const SizedBox(height: 10),

                    _label('PAYE Tax (UGX)'),
                    TextFormField(controller: _paye, decoration: _dec(hint: '0'), keyboardType: TextInputType.number),
                    const SizedBox(height: 10),

                    _label('NSSF (UGX)'),
                    TextFormField(controller: _nssf, decoration: _dec(hint: '0'), keyboardType: TextInputType.number),
                    const SizedBox(height: 10),

                    _label('Other Deductions (UGX)'),
                    TextFormField(controller: _other, decoration: _dec(hint: 'Loan repayment, advance, etc.'), keyboardType: TextInputType.number),

                    const SizedBox(height: 8),
                    _totalBox('Total Deductions', _totalDed, AppColors.error),

                    // Net pay highlight
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        const Text('NET PAY', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text('UGX ${_fmt.format(_net)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      ]),
                    ),

                    const SizedBox(height: 20),
                    _section('Payment Details', Icons.credit_card_rounded, const Color(0xFF8B5CF6)),
                    const SizedBox(height: 10),

                    _label('Payment Method'),
                    DropdownButtonFormField<String>(
                      value: _method,
                      hint: const Text('Select method'),
                      decoration: _dec(),
                      items: const [
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'mobile_money',  child: Text('Mobile Money')),
                        DropdownMenuItem(value: 'cash',          child: Text('Cash')),
                        DropdownMenuItem(value: 'cheque',        child: Text('Cheque')),
                      ],
                      onChanged: (v) => setState(() => _method = v),
                    ),
                    const SizedBox(height: 10),

                    _label('Reference / Receipt No.'),
                    TextFormField(controller: _ref, decoration: _dec(hint: 'e.g. TXN-20260601-001')),
                    const SizedBox(height: 10),

                    _label('Payment Date'),
                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _payDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (d != null) setState(() => _payDate = d);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(8), color: Colors.white),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd MMM yyyy').format(_payDate), style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await widget.onSave({
      'employee_id':      _empId,
      'client_id':        _clientId,
      'period_month':     _month,
      'period_year':      _year,
      'basic_salary':     double.tryParse(_basic.text) ?? 0,
      'allowances':       double.tryParse(_allow.text) ?? 0,
      'paye_tax':         double.tryParse(_paye.text) ?? 0,
      'nssf':             double.tryParse(_nssf.text) ?? 0,
      'other_deductions': double.tryParse(_other.text) ?? 0,
      'payment_method':   _method,
      'payment_reference':_ref.text.trim().isEmpty ? null : _ref.text.trim(),
      'payment_date':     DateFormat('yyyy-MM-dd').format(_payDate),
    });
    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.pop(context);
    }
  }
}

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
);

Widget _section(String title, IconData icon, Color color) => Row(
  children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 6),
    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
  ],
);

Widget _totalBox(String label, double value, Color color) {
  final fmt = NumberFormat('#,##0', 'en');
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        const Spacer(),
        Text('UGX ${fmt.format(value)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    ),
  );
}
