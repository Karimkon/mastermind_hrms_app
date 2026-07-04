import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/admin_provider.dart';

class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(adminDepartmentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Departments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Department'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          deptsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (depts) {
              if (depts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.corporate_fare_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No departments yet', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                ),
                itemCount: depts.length,
                itemBuilder: (_, i) => _DeptCard(dept: depts[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Department', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Department Name')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ok = await ref.read(adminActionsProvider.notifier).createDepartment({
                'name': nameCtrl.text,
                'description': descCtrl.text,
              });
              if (context.mounted) {
                Navigator.pop(context);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Department created'), backgroundColor: AppColors.success));
                  ref.invalidate(adminDepartmentsProvider);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _DeptCard extends StatelessWidget {
  final Map<String, dynamic> dept;
  const _DeptCard({required this.dept});

  @override
  Widget build(BuildContext context) {
    final employeeCount = dept['employees_count'] ?? dept['employee_count'] ?? 0;

    return Container(
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 22),
              ),
              const Spacer(),
              const Icon(Icons.corporate_fare_rounded, color: AppColors.textMuted, size: 18),
            ],
          ),
          const Spacer(),
          Text(dept['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          if (dept['description'] != null)
            Text(dept['description'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.people_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('$employeeCount employees', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              if (dept['head'] != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.person_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(child: Text(dept['head'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
