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
  bool _saving = false;

  /*
   | One controller per typed field and one value per dropdown, both keyed by
   | the name the server reads.
   |
   | This screen used to carry five controllers by hand — name, name, email,
   | phone, address — while the same account manager on the browser had the
   | whole record in front of them: next of kin, NSSF and TIN, the bank
   | account, the employment status, the salary. Five of forty, and one of
   | the five was a lie: the Work Email box posted `email`, which the API's
   | update list did not contain, so it was dropped on the floor every time
   | and the screen still said "Employee updated".
   |
   | Driving the form off _formSections means the two forms are one list
   | apart rather than two implementations apart.
   */
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, String> _choice = {};

  @override
  void initState() {
    super.initState();
    for (final f in _formSections.expand((s) => s.fields)) {
      final initial = widget.emp.text(f.readKey) ?? '';
      if (f.kind == _Kind.choice) {
        // An unrecognised stored value is kept rather than snapped to the
        // first option: silently rewriting somebody's status on open is how
        // a record changes without anybody deciding to change it.
        _choice[f.key] = f.options.any((o) => o.value == initial)
            ? initial
            : (initial.isEmpty ? f.options.first.value : initial);
      } else {
        _ctrl[f.key] = TextEditingController(text: initial);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _state => _choice['status'] ?? 'active';

  /// Whether a field is on the form as it currently stands.
  ///
  /// The reason for ending a contract has no meaning unless the contract is
  /// being ended, and a hold's end date has none unless somebody is on hold.
  /// Hidden fields are not posted either, so re-saving an active employee
  /// cannot carry last year's termination reason back up to the server.
  bool _applies(_Fld f) => f.onlyWhenState == null || f.onlyWhenState == _state;

  Future<void> _saveChanges() async {
    final problem = _firstProblem();
    if (problem != null) {
      _say(problem, AppColors.error);
      return;
    }

    final data = <String, dynamic>{};
    for (final f in _formSections.expand((s) => s.fields)) {
      if (!_applies(f)) continue;
      data[f.key] = f.kind == _Kind.choice
          ? (_choice[f.key] ?? '')
          : _ctrl[f.key]!.text.trim();
    }

    setState(() => _saving = true);
    final result = await ref
        .read(employeeActionsProvider.notifier)
        .updateEmployee(widget.emp.id, data);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.ok) {
      _say(result.message, AppColors.error);
      return;
    }

    setState(() => _editMode = false);
    // The server's own sentence: for an account manager this says the edit
    // went to HR and the record has not moved, which is not something the
    // phone should be guessing at.
    _say(result.message, AppColors.success);
    ref.invalidate(employeeDetailProvider(widget.emp.id));
  }

  /// The first thing wrong with the form, or null. The server checks all of
  /// this again; catching it here saves a round trip and a scroll.
  String? _firstProblem() {
    if ((_ctrl['first_name']?.text.trim() ?? '').isEmpty) {
      return 'A first name is needed.';
    }
    if ((_ctrl['last_name']?.text.trim() ?? '').isEmpty) {
      return 'A last name is needed.';
    }
    if (_state == 'terminated' &&
        (_ctrl['termination_reason']?.text.trim() ?? '').isEmpty) {
      return 'Give a reason for ending this contract.';
    }
    return null;
  }

  void _say(String message, Color colour) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colour,
        duration: const Duration(seconds: 5),
      ),
    );
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
          const SizedBox(height: 12),
          // Read-only, but shown: a form that can change a bank account while
          // the screen behind it cannot show one makes every edit blind.
          _buildSection(
            title: 'Emergency & Next of Kin',
            icon: Icons.emergency_outlined,
            children: [
              _optionalRow('Emergency Contact', emp.text('emergency_contact_name')),
              _optionalRow('Emergency Phone', emp.text('emergency_contact_phone')),
              _optionalRow('Next of Kin', emp.text('next_of_kin_name')),
              _optionalRow('Relationship', emp.text('next_of_kin_relation')),
              _optionalRow('Next of Kin Phone', emp.text('next_of_kin_phone')),
            ].whereType<Widget>().toList(),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Statutory',
            icon: Icons.badge_outlined,
            children: [
              _optionalRow('NSSF Number', emp.text('nssf_number')),
              _optionalRow('TIN Number', emp.text('tin_number')),
              _optionalRow('National ID', emp.text('national_id')),
              _optionalRow('Passport', emp.text('passport_number')),
            ].whereType<Widget>().toList(),
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Banking & Payment',
            icon: Icons.account_balance_outlined,
            children: [
              _optionalRow('Payment Mode',
                  emp.text('payment_mode') == null ? null : _formatLabel(emp.text('payment_mode')!)),
              _optionalRow('Mobile Money', emp.text('mobile_money_number')),
              _optionalRow('Bank', emp.text('bank_name')),
              _optionalRow('Account Number', emp.text('bank_account')),
              _optionalRow('Branch', emp.text('bank_branch')),
              _optionalRow('Account Name', emp.text('account_name')),
            ].whereType<Widget>().toList(),
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

  /// A row, or nothing at all when the field was never filled in. Returning
  /// null and filtering with whereType keeps the section's own "no children,
  /// no card" rule working, so an employee with no bank details does not get
  /// an empty Banking heading.
  Widget? _optionalRow(String label, String? value) =>
      (value == null || value.isEmpty) ? null : _infoRow(label, value);

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
          if (widget.emp.editsNeedApproval) _approvalNotice(),
          for (final section in _formSections) ...[
            _buildEditSection(
              title: section.title,
              icon: section.icon,
              children: [
                for (final field in section.fields)
                  if (_applies(field)) _control(field),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.emp.editsNeedApproval ? 'Send for approval' : 'Save Changes',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _saving ? null : () => setState(() => _editMode = false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Said before they start typing, not after they press Save.
  Widget _approvalNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Changes here are sent for approval. Nothing on the record moves '
              'until they are approved.',
              style: TextStyle(fontSize: 12, color: AppColors.info, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// The right control for one field.
  Widget _control(_Fld f) {
    if (f.kind == _Kind.choice) {
      return _editChoice(f);
    }
    if (f.kind == _Kind.date) {
      return _editDate(f);
    }
    return _editField(
      f.label,
      _ctrl[f.key]!,
      keyboardType: switch (f.kind) {
        _Kind.email => TextInputType.emailAddress,
        _Kind.phone => TextInputType.phone,
        _Kind.number => TextInputType.number,
        _ => null,
      },
      hint: f.hint,
    );
  }

  Widget _editChoice(_Fld f) {
    final value = _choice[f.key];
    final known = f.options.any((o) => o.value == value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(f.label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: known ? value : null,
            isExpanded: true,
            decoration: _boxDecoration(),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            items: [
              for (final o in f.options)
                DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _choice[f.key] = v ?? ''),
          ),
          if (f.hint != null) _hint(f.hint!),
          // Only ever seen when the stored value is not one this form offers.
          if (!known && (value ?? '').isNotEmpty) _hint('Currently: $value'),
        ],
      ),
    );
  }

  Widget _editDate(_Fld f) {
    final ctrl = _ctrl[f.key]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(f.label),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            readOnly: true,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: _boxDecoration().copyWith(
              hintText: 'Not set',
              suffixIcon: ctrl.text.isEmpty
                  ? const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textMuted)
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                      tooltip: 'Clear',
                      onPressed: () => setState(() => ctrl.clear()),
                    ),
            ),
            onTap: () => _pickDate(ctrl),
          ),
          if (f.hint != null) _hint(f.hint!),
        ],
      ),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(ctrl.text.trim());

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      // Wide enough for a date of birth at one end and a contract running
      // years out at the other.
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year + 20),
    );

    if (picked == null) return;
    // The format the server reads, not the phone's locale.
    setState(() => ctrl.text = picked.toIso8601String().split('T').first);
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3)),
      );

  InputDecoration _boxDecoration() => InputDecoration(
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
      );

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

  Widget _editField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: _boxDecoration(),
          ),
          if (hint != null) _hint(hint),
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

// ─────────────────────────────────────────────────────────────────────────
// What an employee record is, as far as this form is concerned.
//
// The same fields, in the same order, under the same headings as the browser
// form at /account-manager/employees/{id} — because they are the same job
// done in two places, and the moment they stop matching somebody is told
// "do it on the laptop instead". The keys are the names the server reads in
// AccountManagerController::applyEmployeeEdit(), which both this and that
// form now post to.
// ─────────────────────────────────────────────────────────────────────────

enum _Kind { text, email, phone, number, date, choice }

class _Opt {
  final String value;
  final String label;
  const _Opt(this.value, this.label);
}

class _Fld {
  /// The name this posts under.
  final String key;

  /// The name it is read back under, when that differs. The login address is
  /// the only one: it comes down as `email` because it lives on the user, and
  /// goes up as `login_email` because that is what tells the server to move it.
  final String readKey;

  final String label;
  final _Kind kind;
  final List<_Opt> options;
  final String? hint;

  /// Shown, and posted, only while the status dropdown reads this.
  final String? onlyWhenState;

  const _Fld(
    this.key,
    this.label, {
    this.kind = _Kind.text,
    this.options = const [],
    this.hint,
    this.onlyWhenState,
    String? readKey,
  }) : readKey = readKey ?? key;
}

class _Sect {
  final String title;
  final IconData icon;
  final List<_Fld> fields;
  const _Sect(this.title, this.icon, this.fields);
}

const _formSections = <_Sect>[
  _Sect('Personal Details', Icons.person_outline_rounded, [
    _Fld('title', 'Title', kind: _Kind.choice, options: [
      _Opt('', '—'),
      _Opt('Mr', 'Mr'),
      _Opt('Mrs', 'Mrs'),
      _Opt('Ms', 'Ms'),
      _Opt('Dr', 'Dr'),
      _Opt('Prof', 'Prof'),
    ]),
    _Fld('first_name', 'First Name'),
    _Fld('middle_name', 'Middle Name'),
    _Fld('last_name', 'Last Name'),
    _Fld('date_of_birth', 'Date of Birth', kind: _Kind.date),
    _Fld('gender', 'Gender', kind: _Kind.choice, options: [
      _Opt('', '—'),
      _Opt('male', 'Male'),
      _Opt('female', 'Female'),
      _Opt('other', 'Other'),
    ]),
    _Fld('marital_status', 'Marital Status', kind: _Kind.choice, options: [
      _Opt('', '—'),
      _Opt('single', 'Single'),
      _Opt('married', 'Married'),
      _Opt('divorced', 'Divorced'),
      _Opt('widowed', 'Widowed'),
    ]),
    _Fld('nationality', 'Nationality'),
    _Fld('religion', 'Religion'),
  ]),

  _Sect('Contact', Icons.contact_phone_outlined, [
    _Fld('phone', 'Phone Number', kind: _Kind.phone),
    _Fld('personal_email', 'Personal Email', kind: _Kind.email),
    _Fld(
      'login_email',
      'Work / Payslip Email',
      readKey: 'email',
      kind: _Kind.email,
      hint: 'Where payslips are sent, and how they sign in. '
          'Applied straight away, not held for approval.',
    ),
    _Fld('address', 'Address'),
    _Fld('city', 'City'),
    _Fld('country', 'Country'),
  ]),

  _Sect('Emergency & Next of Kin', Icons.emergency_outlined, [
    _Fld('emergency_contact_name', 'Emergency Contact'),
    _Fld('emergency_contact_phone', 'Emergency Contact Phone', kind: _Kind.phone),
    _Fld('next_of_kin_name', 'Next of Kin'),
    _Fld('next_of_kin_relation', 'Relationship', hint: 'Wife / Brother / Mother'),
    _Fld('next_of_kin_phone', 'Next of Kin Phone', kind: _Kind.phone),
    _Fld('next_of_kin_email', 'Next of Kin Email', kind: _Kind.email),
  ]),

  _Sect('Employment', Icons.work_outline_rounded, [
    // Reads `state`, posts `status`: a hold is a flag beside that column
    // rather than a value in it, and the server pulls the two apart again.
    _Fld('status', 'Status', readKey: 'state', kind: _Kind.choice, options: [
      _Opt('active', 'Active'),
      _Opt('on_leave', 'On Leave'),
      _Opt('on_hold', 'On Hold — off payroll, still staff'),
      _Opt('suspended', 'Suspended'),
      _Opt('terminated', 'Terminated — contract ended'),
    ]),
    _Fld('hold_end_date', 'Hold Ends', kind: _Kind.date,
        onlyWhenState: 'on_hold',
        hint: 'Leave blank to hold indefinitely. They stay on the books but '
            'are left out of payroll until it is lifted.'),
    _Fld('hold_reason', 'Reason for the Hold', onlyWhenState: 'on_hold'),
    _Fld('end_date', 'Last Working Day', kind: _Kind.date,
        onlyWhenState: 'terminated',
        hint: 'Left blank, today is used.'),
    _Fld('termination_reason', 'Reason for Ending the Contract',
        onlyWhenState: 'terminated',
        hint: 'Required. They come off payroll and stay off.'),
    _Fld('employment_type', 'Employment Type', kind: _Kind.choice, options: [
      _Opt('full_time', 'Full Time'),
      _Opt('part_time', 'Part Time'),
      _Opt('contract', 'Contract'),
      _Opt('casual', 'Casual'),
      _Opt('intern', 'Intern'),
    ]),
    _Fld('hire_date', 'Hire Date', kind: _Kind.date),
    _Fld('contract_end_date', 'Contract End Date', kind: _Kind.date),
    _Fld('work_location', 'Work Location / Site'),
    _Fld('basic_salary', 'Gross Salary (UGX)',
        kind: _Kind.number,
        hint: 'The full monthly figure before PAYE, NSSF and LST.'),
    _Fld('salary_type', 'Salary Type', kind: _Kind.choice, options: [
      _Opt('monthly', 'Monthly'),
      _Opt('daily', 'Daily'),
      _Opt('hourly', 'Hourly'),
    ]),
  ]),

  _Sect('Statutory', Icons.badge_outlined, [
    _Fld('nssf_number', 'NSSF Number'),
    _Fld('tin_number', 'TIN Number'),
    _Fld('national_id', 'National ID'),
    _Fld('passport_number', 'Passport Number'),
  ]),

  _Sect('Banking & Payment', Icons.account_balance_outlined, [
    _Fld('payment_mode', 'Payment Mode', kind: _Kind.choice, options: [
      _Opt('bank', 'Bank Transfer (EFT)'),
      _Opt('mtn', 'MTN Mobile Money'),
      _Opt('airtel', 'Airtel Mobile Money'),
      _Opt('cash', 'Cash'),
      _Opt('cheque', 'Cheque'),
    ]),
    _Fld('mobile_money_number', 'Mobile Money Number', kind: _Kind.phone),
    _Fld('bank_name', 'Bank Name'),
    _Fld('bank_account', 'Account Number'),
    _Fld('bank_branch', 'Branch'),
    _Fld('account_name', 'Account Name'),
  ]),
];
