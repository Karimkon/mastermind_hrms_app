import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/admin_provider.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = 'all';

  String get _paramsKey {
    final parts = <String>[];
    if (_roleFilter != 'all') parts.add('role=$_roleFilter');
    if (_searchCtrl.text.isNotEmpty) parts.add('search=${_searchCtrl.text}');
    return parts.join('&');
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider(_paramsKey));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _roleFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'super-admin', child: Text('Super Admin')),
                  DropdownMenuItem(value: 'hr-admin', child: Text('HR Admin')),
                  DropdownMenuItem(value: 'payroll-officer', child: Text('Payroll Officer')),
                  DropdownMenuItem(value: 'recruiter', child: Text('Recruiter')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'client', child: Text('Client')),
                ],
                onChanged: (v) => setState(() => _roleFilter = v ?? 'all'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add User'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          usersAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (users) {
              if (users.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.manage_accounts_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No users found', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
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
                    _TableHeader(),
                    ...users.map((u) => _UserRow(user: u)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _AddUserDialog(ref: ref));
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: _H('User')),
          Expanded(flex: 2, child: _H('Email')),
          Expanded(child: _H('Role')),
          Expanded(child: _H('Status')),
          Expanded(child: _H('Joined')),
          SizedBox(width: 60),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary));
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final roles = (user['roles'] as List? ?? []).join(', ');
    final status = user['status'] as String? ?? 'active';
    final name = user['name'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: AppColors.infoLight, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
          )),
          Expanded(flex: 2, child: Text(user['email'] as String? ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(12)),
            child: Text(roles, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          )),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: status == 'active' ? AppColors.successLight : AppColors.errorLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status[0].toUpperCase() + status.substring(1),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status == 'active' ? AppColors.success : AppColors.error)),
          )),
          Expanded(child: Text(user['created_at'] as String? ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
          SizedBox(width: 60, child: PopupMenuButton<String>(
            onSelected: (_) {},
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'reset', child: Text('Reset Password')),
              PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
            ],
            child: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 18),
          )),
        ],
      ),
    );
  }
}

class _AddUserDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AddUserDialog({required this.ref});

  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'employee';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add User', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name'), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'super-admin', child: Text('Super Admin')),
                  DropdownMenuItem(value: 'hr-admin', child: Text('HR Admin')),
                  DropdownMenuItem(value: 'payroll-officer', child: Text('Payroll Officer')),
                  DropdownMenuItem(value: 'recruiter', child: Text('Recruiter')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  DropdownMenuItem(value: 'client', child: Text('Client')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'employee'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create User'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await widget.ref.read(adminActionsProvider.notifier).createUser({
      'name': _nameCtrl.text,
      'email': _emailCtrl.text,
      'password': _passCtrl.text,
      'password_confirmation': _passCtrl.text,
      'role': _role,
    });
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created'), backgroundColor: AppColors.success));
        widget.ref.invalidate(adminUsersProvider);
      }
    }
  }
}
