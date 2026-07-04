import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';

class AmEmployeesScreen extends ConsumerStatefulWidget {
  const AmEmployeesScreen({super.key});

  @override
  ConsumerState<AmEmployeesScreen> createState() => _AmEmployeesScreenState();
}

class _AmEmployeesScreenState extends ConsumerState<AmEmployeesScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  int? _selectedClientId;
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadClients();
    _load(reset: true);
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_loadingMore && _page < _lastPage) _loadNextPage();
    }
  }

  Future<void> _loadClients() async {
    try {
      final resp = await ApiService.get(ApiConstants.amClients);
      if (mounted) {
        setState(() {
          _clients = (resp.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() { _loading = true; _error = null; _page = 1; });
    }
    try {
      final params = <String, dynamic>{
        'page': 1,
        'per_page': 20,
        if (_searchCtrl.text.isNotEmpty) 'search': _searchCtrl.text.trim(),
        if (_statusFilter != 'all') 'status': _statusFilter,
        if (_selectedClientId != null) 'client_id': _selectedClientId,
      };
      final resp = await ApiService.get(ApiConstants.amEmployees, params: params);
      final d = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _employees = (d['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _lastPage = d['last_page'] ?? 1;
          _page = 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _loadingMore = true);
    try {
      final params = <String, dynamic>{
        'page': _page + 1,
        'per_page': 20,
        if (_searchCtrl.text.isNotEmpty) 'search': _searchCtrl.text.trim(),
        if (_statusFilter != 'all') 'status': _statusFilter,
        if (_selectedClientId != null) 'client_id': _selectedClientId,
      };
      final resp = await ApiService.get(ApiConstants.amEmployees, params: params);
      final d = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _employees.addAll((d['data'] as List).map((e) => Map<String, dynamic>.from(e)));
          _page++;
          _lastPage = d['last_page'] ?? 1;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildFilters()),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(child: _ErrorState(message: _error!, onRetry: () => _load(reset: true)))
            else if (_employees.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _EmployeeCard(employee: _employees[i]),
                    childCount: _employees.length,
                  ),
                ),
              ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Employees', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text('${_employees.length} employee${_employees.length == 1 ? '' : 's'} across your managed clients',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name or employee number…',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () { _searchCtrl.clear(); _load(reset: true); },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client filter chips
          if (_clients.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All Companies',
                    selected: _selectedClientId == null,
                    onTap: () { setState(() => _selectedClientId = null); _load(reset: true); },
                  ),
                  ..._clients.map((c) => _FilterChip(
                    label: c['company_name'] ?? '',
                    selected: _selectedClientId == c['id'],
                    onTap: () { setState(() => _selectedClientId = c['id'] as int?); _load(reset: true); },
                    color: AppColors.primary,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in ['all', 'active', 'on_leave', 'suspended', 'inactive'])
                  _FilterChip(
                    label: _statusLabel(s),
                    selected: _statusFilter == s,
                    onTap: () { setState(() => _statusFilter = s); _load(reset: true); },
                    color: _statusColor(s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'all': return 'All';
      case 'active': return 'Active';
      case 'on_leave': return 'On Leave';
      case 'suspended': return 'Suspended';
      case 'inactive': return 'Inactive';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active': return AppColors.success;
      case 'on_leave': return AppColors.warning;
      case 'suspended': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }
}

// ─── Employee Card ────────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  const _EmployeeCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    final status = employee['status'] ?? 'active';
    final avatarUrl = employee['avatar_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundImage: (avatarUrl != null && avatarUrl.toString().isNotEmpty)
                  ? NetworkImage(avatarUrl.toString())
                  : null,
              backgroundColor: AppColors.infoLight,
              child: (avatarUrl == null || avatarUrl.toString().isEmpty)
                  ? Text(_initials(employee['full_name'] ?? ''),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14))
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(employee['full_name'] ?? '—',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                      ),
                      _StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(employee['emp_number'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${employee['designation'] ?? '—'} · ${employee['department'] ?? '—'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if ((employee['company'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_city_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(employee['company'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
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

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label;
    switch (status) {
      case 'active':    bg = AppColors.successLight; fg = AppColors.success;  label = 'Active';    break;
      case 'on_leave':  bg = AppColors.warningLight; fg = AppColors.warning;  label = 'On Leave';  break;
      case 'suspended': bg = AppColors.errorLight;   fg = AppColors.error;    label = 'Suspended'; break;
      default:          bg = AppColors.cardBorder;   fg = AppColors.textMuted; label = 'Inactive'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.inputBorder, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? color : AppColors.textSecondary)),
      ),
    );
  }
}

// ─── Error & Empty States ─────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 56, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('No employees found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          SizedBox(height: 4),
          Text('Try adjusting your filters', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
