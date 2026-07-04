import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/employee_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/employee_model.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  final int employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(employeeDetailProvider(employeeId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: empAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (emp) {
          if (emp == null) {
            return const Center(child: Text('Employee not found'));
          }
          return _DetailBody(emp: emp);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  final EmployeeModel emp;
  const _DetailBody({required this.emp});

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _editMode = false;

  // Edit form controllers
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.emp.firstName ?? '');
    _lastNameCtrl  = TextEditingController(text: widget.emp.lastName ?? '');
    _emailCtrl     = TextEditingController(text: widget.emp.email ?? '');
    _phoneCtrl     = TextEditingController(text: widget.emp.phone ?? '');
    _addressCtrl   = TextEditingController(text: widget.emp.address ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final notifier = ref.read(employeeActionsProvider.notifier);
    final data = {
      'first_name': _firstNameCtrl.text.trim(),
      'last_name':  _lastNameCtrl.text.trim(),
      'email':      _emailCtrl.text.trim(),
      'phone':      _phoneCtrl.text.trim(),
      'address':    _addressCtrl.text.trim(),
    };
    final ok = await notifier.updateEmployee(widget.emp.id, data);
    if (!mounted) return;
    if (ok) {
      setState(() => _editMode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee updated'), backgroundColor: AppColors.success),
      );
      // Refresh detail
      ref.invalidate(employeeDetailProvider(widget.emp.id));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    final user = ref.watch(authProvider).user;
    final canEdit = user?.isAdmin == true || user?.hasAnyRole(['hr', 'account-manager']) == true;

    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(context, emp, canEdit),
          Expanded(
            child: _editMode
                ? _buildEditForm(context)
                : _buildViewContent(emp),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, EmployeeModel emp, bool canEdit) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              emp.fullName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canEdit)
            _editMode
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _editMode = false),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                    tooltip: 'Edit',
                    onPressed: () => setState(() => _editMode = true),
                  ),
        ],
      ),
    );
  }

  Widget _buildViewContent(EmployeeModel emp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(emp),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Job Information',
            icon: Icons.work_outline_rounded,
            children: [
              _infoRow('Employee #', emp.empNumber),
              if (emp.department != null) _infoRow('Department', emp.department!),
              if (emp.designation != null) _infoRow('Designation', emp.designation!),
              if (emp.employmentType != null) _infoRow('Employment Type', _formatLabel(emp.employmentType!)),
              if (emp.hireDate != null) _infoRow('Hire Date', emp.hireDate!),
              if (emp.clientName != null) _infoRow('Client / Company', emp.clientName!),
              if (emp.manager != null) _infoRow('Manager', emp.manager!),
            ],
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Personal Information',
            icon: Icons.person_outline_rounded,
            children: [
              if (emp.gender != null) _infoRow('Gender', _formatLabel(emp.gender!)),
              if (emp.dateOfBirth != null) _infoRow('Date of Birth', emp.dateOfBirth!),
              if (emp.address != null) _infoRow('Address', emp.address!),
              if (emp.city != null) _infoRow('City', emp.city!),
              if (emp.country != null) _infoRow('Country', emp.country!),
            ],
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Contact Information',
            icon: Icons.contact_phone_outlined,
            children: [
              if (emp.email != null) _infoRow('Work Email', emp.email!),
              if (emp.personalEmail != null) _infoRow('Personal Email', emp.personalEmail!),
              if (emp.phone != null) _infoRow('Phone', emp.phone!),
            ],
          ),
          if (emp.bio != null && emp.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSection(
              title: 'Bio',
              icon: Icons.notes_rounded,
              children: [
                Text(emp.bio!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(EmployeeModel emp) {
    final initials = _initials(emp.fullName);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: emp.avatarUrl != null ? NetworkImage(emp.avatarUrl!) : null,
            child: emp.avatarUrl == null
                ? Text(initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary))
                : null,
          ),
          const SizedBox(height: 12),
          Text(emp.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(emp.empNumber, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          if (emp.designation != null) ...[
            const SizedBox(height: 2),
            Text(emp.designation!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          _StatusBadge(status: emp.status),
          if (emp.clientName != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(emp.clientName!, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEditSection(
            title: 'Personal Details',
            icon: Icons.person_outline_rounded,
            children: [
              _editField('First Name', _firstNameCtrl),
              _editField('Last Name', _lastNameCtrl),
              _editField('Address', _addressCtrl),
            ],
          ),
          const SizedBox(height: 12),
          _buildEditSection(
            title: 'Contact',
            icon: Icons.contact_phone_outlined,
            children: [
              _editField('Work Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
              _editField('Phone', _phoneCtrl, keyboardType: TextInputType.phone),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() => _editMode = false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  String _formatLabel(String s) {
    return s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'active'     => (AppColors.successLight, AppColors.success, 'Active'),
      'on_leave'   => (AppColors.warningLight, AppColors.warning, 'On Leave'),
      'suspended'  => (const Color(0xFFFFF7ED), const Color(0xFFF97316), 'Suspended'),
      'terminated' => (AppColors.errorLight, AppColors.error, 'Terminated'),
      _            => (AppColors.infoLight, AppColors.info, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
