import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/admin_provider.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _searchCtrl = TextEditingController();

  String get _paramsKey =>
      _searchCtrl.text.isNotEmpty ? 'search=${_searchCtrl.text}' : '';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider(_paramsKey));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search audit logs...',
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          logsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No audit logs yet', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
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
                child: Column(children: logs.map((l) => _AuditRow(log: l)).toList()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final Map<String, dynamic> log;
  const _AuditRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final event = log['event'] as String? ?? log['action'] as String? ?? 'action';
    final (bg, fg) = switch (event.toLowerCase()) {
      'created' || 'create' => (AppColors.successLight, AppColors.success),
      'deleted' || 'delete' => (AppColors.errorLight, AppColors.error),
      'updated' || 'update' => (AppColors.warningLight, AppColors.warning),
      _ => (AppColors.infoLight, AppColors.info),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(event[0].toUpperCase() + event.substring(1), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log['description'] as String? ?? log['model_type'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (log['causer'] != null)
                  Text('by ${log['causer']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(log['created_at'] as String? ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
