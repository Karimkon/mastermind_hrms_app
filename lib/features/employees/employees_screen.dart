import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/employee_provider.dart';
import '../../core/models/employee_model.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  int? _clientFilter;

  String get _paramsKey {
    final parts = <String>[];
    if (_statusFilter != 'all') parts.add('status=$_statusFilter');
    if (_searchCtrl.text.isNotEmpty) parts.add('search=${Uri.encodeComponent(_searchCtrl.text)}');
    if (_clientFilter != null) parts.add('client_id=$_clientFilter');
    return parts.join('&');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return isMobile ? _buildMobile() : _buildDesktop();
  }

  // ── MOBILE ────────────────────────────────────────────────────────────────
  Widget _buildMobile() {
    final employeesAsync = ref.watch(employeeListProvider(_paramsKey));
    final clientsAsync   = ref.watch(clientsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employees',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  employeesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) => Text(
                      '${list.length} employee${list.length == 1 ? '' : 's'} across your managed clients',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or employee numb...',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),

            // ── Company filter chips ──────────────────────────────────────
            clientsAsync.when(
              loading: () => const SizedBox(height: 8),
              error: (_, __) => const SizedBox(height: 8),
              data: (clients) {
                if (clients.isEmpty) return const SizedBox(height: 8);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CompanyChip(
                          label: 'All Companies',
                          selected: _clientFilter == null,
                          onTap: () => setState(() => _clientFilter = null),
                        ),
                        const SizedBox(width: 8),
                        ...clients.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CompanyChip(
                            label: c['company_name'] as String? ?? '',
                            selected: _clientFilter == (c['id'] as int?),
                            onTap: () => setState(() => _clientFilter = c['id'] as int?),
                          ),
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Status filter chips ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 0, 8),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final s in ['all', 'active', 'on_leave', 'suspended'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _StatusChip(
                          label: s == 'all' ? 'All' : s == 'on_leave' ? 'On Leave' : s[0].toUpperCase() + s.substring(1),
                          selected: _statusFilter == s,
                          onTap: () => setState(() => _statusFilter = s),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Employee list ──────────────────────────────────────────────
            Expanded(
              child: employeesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                data: (employees) {
                  if (employees.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 56, color: Color(0xFFD1D5DB)),
                          SizedBox(height: 12),
                          Text('No employees found', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: employees.length,
                    itemBuilder: (_, i) => _EmployeeListTile(employee: employees[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DESKTOP ──────────────────────────────────────────────────────────────
  Widget _buildDesktop() {
    final employeesAsync = ref.watch(employeeListProvider(_paramsKey));
    final deptsAsync     = ref.watch(departmentsProvider);

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
                    hintText: 'Search employees...',
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              deptsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (depts) => DropdownButton<int?>(
                  value: _clientFilter,
                  underline: const SizedBox(),
                  hint: const Text('All Clients'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All Clients')),
                    ...ref.watch(clientsProvider).valueOrNull?.map((c) =>
                        DropdownMenuItem<int?>(value: c['id'] as int?, child: Text(c['company_name'] as String? ?? ''))) ?? [],
                  ],
                  onChanged: (v) => setState(() => _clientFilter = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                  DropdownMenuItem(value: 'terminated', child: Text('Terminated')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddEmployeeDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Employee'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          employeesAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (employees) => _EmployeeGrid(employees: employees),
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _AddEmployeeDialog(ref: ref));
  }
}

// ── Company filter chip ────────────────────────────────────────────────────
class _CompanyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CompanyChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF1A1A2E) : const Color(0xFFD1D5DB)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF374151),
            )),
      ),
    );
  }
}

// ── Status filter chip ────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF1A1A2E) : const Color(0xFFD1D5DB)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF374151),
            )),
      ),
    );
  }
}

// ── Mobile list tile ──────────────────────────────────────────────────────
class _EmployeeListTile extends StatelessWidget {
  final EmployeeModel employee;
  const _EmployeeListTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    final e = employee;
    final initials = e.fullName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return GestureDetector(
      onTap: () => context.push('/employees/${e.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE8EAF6),
              backgroundImage: (e.avatarUrl != null && e.avatarUrl!.isNotEmpty) ? NetworkImage(e.avatarUrl!) : null,
              child: (e.avatarUrl == null || e.avatarUrl!.isEmpty)
                  ? Text(initials, style: const TextStyle(color: Color(0xFF3F51B5), fontSize: 16, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(e.fullName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                      ),
                      _StatusBadge(status: e.status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(e.empNumber,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 13, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text('— ', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      Flexible(
                        child: Text(e.department ?? '—',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (e.clientName != null && e.clientName!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.business_rounded, size: 13, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(e.clientName!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label;
    switch (status) {
      case 'active':
        bg = const Color(0xFFDCFCE7); fg = const Color(0xFF15803D); label = 'Active'; break;
      case 'on_leave':
        bg = const Color(0xFFFEF3C7); fg = const Color(0xFFD97706); label = 'On Leave'; break;
      case 'suspended':
        bg = const Color(0xFFFFF7ED); fg = const Color(0xFFEA580C); label = 'Suspended'; break;
      case 'terminated':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFDC2626); label = 'Terminated'; break;
      default:
        bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280); label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ── Desktop grid ──────────────────────────────────────────────────────────
class _EmployeeGrid extends StatelessWidget {
  final List<EmployeeModel> employees;
  const _EmployeeGrid({required this.employees});

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: Column(children: [
            Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No employees found', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
          ]),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Text('${employees.length} employees', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85,
          ),
          itemCount: employees.length,
          itemBuilder: (_, i) => _EmployeeGridCard(employee: employees[i]),
        ),
      ],
    );
  }
}

class _EmployeeGridCard extends StatefulWidget {
  final EmployeeModel employee;
  const _EmployeeGridCard({required this.employee});
  @override State<_EmployeeGridCard> createState() => _EmployeeGridCardState();
}

class _EmployeeGridCardState extends State<_EmployeeGridCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    final initials = e.fullName.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push('/employees/${e.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? AppColors.primary : AppColors.cardBorder),
            boxShadow: _hovered ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.infoLight,
                  backgroundImage: (e.avatarUrl != null && e.avatarUrl!.isNotEmpty) ? NetworkImage(e.avatarUrl!) : null,
                  child: (e.avatarUrl == null || e.avatarUrl!.isEmpty)
                      ? Text(initials, style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(e.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(e.designation ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                Text(e.department ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted), textAlign: TextAlign.center),
                if (e.clientName != null) ...[
                  const SizedBox(height: 4),
                  Text(e.clientName!, style: const TextStyle(fontSize: 11, color: AppColors.primary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Text(e.empNumber, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _StatusBadge(status: e.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add employee dialog (unchanged) ──────────────────────────────────────
class _AddEmployeeDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _AddEmployeeDialog({required this.ref});
  @override ConsumerState<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends ConsumerState<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  int?   _deptId;
  int?   _desigId;
  String _empType = 'full_time';
  bool   _loading = false;

  @override
  Widget build(BuildContext context) {
    final depts  = ref.watch(departmentsProvider).valueOrNull ?? [];
    final desigs = ref.watch(designationsProvider).valueOrNull ?? [];
    return AlertDialog(
      title: const Text('Add New Employee', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: TextFormField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name'), validator: (v) => v?.isEmpty == true ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name'), validator: (v) => v?.isEmpty == true ? 'Required' : null)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v?.isEmpty == true ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(
                value: _deptId,
                decoration: const InputDecoration(labelText: 'Department'),
                items: depts.map((d) => DropdownMenuItem<int>(value: d['id'] as int?, child: Text(d['name'] as String? ?? ''))).toList(),
                onChanged: (v) => setState(() => _deptId = v),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<int>(
                value: _desigId,
                decoration: const InputDecoration(labelText: 'Designation'),
                items: desigs.map((d) => DropdownMenuItem<int>(value: d['id'] as int?, child: Text(d['name'] as String? ?? d['title'] as String? ?? ''))).toList(),
                onChanged: (v) => setState(() => _desigId = v),
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _empType,
              decoration: const InputDecoration(labelText: 'Employment Type'),
              items: const [
                DropdownMenuItem(value: 'full_time', child: Text('Full Time')),
                DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
                DropdownMenuItem(value: 'contract', child: Text('Contract')),
                DropdownMenuItem(value: 'intern', child: Text('Intern')),
              ],
              onChanged: (v) => setState(() => _empType = v ?? 'full_time'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create Employee'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await widget.ref.read(employeeActionsProvider.notifier).createEmployee({
      'first_name': _firstNameCtrl.text,
      'last_name': _lastNameCtrl.text,
      'email': _emailCtrl.text,
      'phone': _phoneCtrl.text,
      if (_deptId != null) 'department_id': _deptId,
      if (_desigId != null) 'designation_id': _desigId,
      'employment_type': _empType,
    });
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee created'), backgroundColor: AppColors.success));
        widget.ref.invalidate(employeeListProvider);
      }
    }
  }
}
