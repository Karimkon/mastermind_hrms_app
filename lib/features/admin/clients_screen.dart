import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/admin_provider.dart';

class AdminClientsScreen extends ConsumerWidget {
  const AdminClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(adminClientsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Client Organizations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddClientDialog(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Client'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          clientsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (clients) {
              if (clients.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.business_center_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No clients yet', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: clients.map((c) => _ClientCard(client: c, ref: ref)).toList());
            },
          ),
        ],
      ),
    );
  }

  void _showAddClientDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl    = TextEditingController();
    final contactCtrl = TextEditingController();
    final emailCtrl   = TextEditingController();
    final phoneCtrl   = TextEditingController();
    final formKey     = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Client Organization'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Company Name *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Person', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final ok = await ref.read(adminActionsProvider.notifier).createClient({
                'company_name':   nameCtrl.text,
                'contact_person': contactCtrl.text,
                'email':          emailCtrl.text,
                'phone':          phoneCtrl.text,
                'status':         'active',
              });
              if (ok) {
                ref.invalidate(adminClientsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Client added'), backgroundColor: AppColors.success));
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Failed to add client'), backgroundColor: AppColors.error));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final WidgetRef ref;
  const _ClientCard({required this.client, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client['company_name'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (client['contact_person'] != null) ...[
                      const Icon(Icons.person_rounded, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(client['contact_person'] as String? ?? '',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                    ],
                    if (client['email'] != null) ...[
                      const Icon(Icons.email_rounded, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(client['email'] as String? ?? '',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${client['employees_count'] ?? 0} assigned',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('${client['jobs_count'] ?? 0} jobs',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'delete') _confirmDelete(context, client['id'] as int);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'view', child: Text('View Details')),
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
            child: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Remove "${client['company_name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(adminActionsProvider.notifier).deleteClient(id);
              if (ok) {
                ref.invalidate(adminClientsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Client removed'), backgroundColor: AppColors.success));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
