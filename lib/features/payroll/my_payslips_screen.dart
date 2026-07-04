import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/providers/payroll_provider.dart';
import '../../core/models/payslip_model.dart';
import '../../core/services/api_service.dart';
import 'package:dio/dio.dart';

class MyPayslipsScreen extends ConsumerWidget {
  const MyPayslipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipsAsync = ref.watch(myPayslipsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          payslipsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (payslips) {
              if (payslips.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(80),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 56, color: AppColors.textMuted),
                        SizedBox(height: 16),
                        Text('No payslips yet', style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: payslips.map((p) => _PayslipCard(payslip: p)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PayslipCard extends StatefulWidget {
  final PayslipModel payslip;
  const _PayslipCard({required this.payslip});

  @override
  State<_PayslipCard> createState() => _PayslipCardState();
}

class _PayslipCardState extends State<_PayslipCard> {
  bool _downloading = false;

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final res = await ApiService.dio.get(
        '${ApiConstants.myPayslips}/${widget.payslip.id}/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/payslip-${widget.payslip.id}.pdf');
      await file.writeAsBytes(res.data as List<int>);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  PayslipModel get payslip => widget.payslip;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en');


    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payslip.period ?? 'Payslip', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (payslip.employee != null)
                        Text(payslip.employee!, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Net Pay', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('UGX ${fmt.format(payslip.netPay)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _downloading ? null : _downloadPdf,
                  icon: _downloading
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                  label: Text(_downloading ? 'Downloading…' : 'PDF',
                      style: const TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Earnings
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EARNINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      _PayItem('Basic Salary', fmt.format(payslip.basicSalary)),
                      _PayItem('Allowances', fmt.format(payslip.totalAllowances)),
                      const Divider(height: 20),
                      _PayItem('Gross Pay', fmt.format(payslip.grossPay), bold: true),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Deductions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DEDUCTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      _PayItem('PAYE (Tax)', fmt.format(payslip.tax)),
                      _PayItem('Other Deductions', fmt.format(payslip.totalDeductions - payslip.tax)),
                      const Divider(height: 20),
                      _PayItem('Total Deductions', fmt.format(payslip.totalDeductions), bold: true, color: AppColors.error),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Net pay box
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('NET PAY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text('UGX ${fmt.format(payslip.netPay)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.success)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayItem extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _PayItem(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          Text(
            'UGX $value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
