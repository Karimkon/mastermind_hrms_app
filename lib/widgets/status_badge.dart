import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge(this.status, {super.key, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final (bg, text) = _colors(status.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color, Color) _colors(String s) => switch (s) {
        'active' || 'approved' || 'hired' || 'clocked_in' || 'present' || 'open' || 'completed' =>
          (AppColors.successLight, AppColors.success),
        'pending' || 'scheduled' || 'enrolled' || 'draft' =>
          (AppColors.warningLight, AppColors.warning),
        'rejected' || 'failed' || 'absent' || 'closed' || 'terminated' =>
          (AppColors.errorLight, AppColors.error),
        'interview' || 'processed' || 'shortlisted' || 'on_leave' =>
          (AppColors.infoLight, AppColors.info),
        _ => (const Color(0xFFF1F5F9), AppColors.textSecondary),
      };
}
