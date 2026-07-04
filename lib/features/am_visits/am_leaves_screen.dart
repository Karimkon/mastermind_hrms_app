import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';

class AmLeavesScreen extends ConsumerStatefulWidget {
  const AmLeavesScreen({super.key});

  @override
  ConsumerState<AmLeavesScreen> createState() => _AmLeavesScreenState();
}

class _AmLeavesScreenState extends ConsumerState<AmLeavesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  int? _selectedClientId;
  String _statusFilter = 'all';
  final _scrollCtrl = ScrollController();
  bool _loadingMore = false;
  late TabController _tabCtrl;

  static const _tabs = ['all', 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _statusFilter = _tabs[_tabCtrl.index]);
        _load(reset: true);
      }
    });
    _loadClients();
    _load(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
    if (reset) setState(() { _loading = true; _error = null; _page = 1; });
    try {
      final params = <String, dynamic>{
        'page': 1,
        'per_page': 20,
        if (_statusFilter != 'all') 'status': _statusFilter,
        if (_selectedClientId != null) 'client_id': _selectedClientId,
      };
      final resp = await ApiService.get(ApiConstants.amLeaves, params: params);
      final d = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _leaves = (d['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
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
        if (_statusFilter != 'all') 'status': _statusFilter,
        if (_selectedClientId != null) 'client_id': _selectedClientId,
      };
      final resp = await ApiService.get(ApiConstants.amLeaves, params: params);
      final d = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _leaves.addAll((d['data'] as List).map((e) => Map<String, dynamic>.from(e)));
          _page++;
          _lastPage = d['last_page'] ?? 1;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _approve(int leaveId) async {
    try {
      await ApiService.post('${ApiConstants.amLeaves}/$leaveId/approve');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave approved successfully'), backgroundColor: AppColors.success),
      );
      _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showRejectDialog(int leaveId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Leave', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide a reason for rejection (optional):', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason…',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.post('${ApiConstants.amLeaves}/$leaveId/reject',
          data: {'reason': reasonCtrl.text.trim().isEmpty ? 'Rejected by Account Manager' : reasonCtrl.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave rejected'), backgroundColor: AppColors.warning),
      );
      _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          if (_clients.isNotEmpty) _buildClientFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leave Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text('Approve or reject leave requests for your employees', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.cardBg,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Pending'),
          Tab(text: 'Approved'),
          Tab(text: 'Rejected'),
        ],
      ),
    );
  }

  Widget _buildClientFilter() {
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: 'All Companies',
              selected: _selectedClientId == null,
              onTap: () { setState(() => _selectedClientId = null); _load(reset: true); },
            ),
            ..._clients.map((c) => _Chip(
              label: c['company_name'] ?? '',
              selected: _selectedClientId == c['id'],
              onTap: () { setState(() => _selectedClientId = c['id'] as int?); _load(reset: true); },
              activeColor: AppColors.primary,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_leaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.beach_access_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              _statusFilter == 'pending' ? 'No pending leave requests' : 'No leave requests found',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text('Pull down to refresh', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        itemCount: _leaves.length + (_loadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _leaves.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          final leave = _leaves[i];
          return _LeaveCard(
            leave: leave,
            onApprove: leave['status'] == 'pending' ? () => _approve(leave['id'] as int) : null,
            onReject:  leave['status'] == 'pending' ? () => _showRejectDialog(leave['id'] as int) : null,
          );
        },
      ),
    );
  }
}

// ─── Leave Card ───────────────────────────────────────────────────────────────

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _LeaveCard({required this.leave, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final status = leave['status'] ?? 'pending';
    final avatarUrl = leave['avatar_url'];
    final fromDate = leave['from_date'] ?? '';
    final toDate   = leave['to_date']   ?? '';
    final days     = leave['days_count'];

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: (avatarUrl != null && avatarUrl.toString().isNotEmpty) ? NetworkImage(avatarUrl.toString()) : null,
                  backgroundColor: AppColors.infoLight,
                  child: (avatarUrl == null || avatarUrl.toString().isEmpty)
                      ? Text(_initials(leave['employee'] ?? ''), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(leave['employee'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                      Text(leave['department'] ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                _LeaveBadge(status: status),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            // Leave details grid
            Row(
              children: [
                _DetailItem(icon: Icons.category_rounded, label: 'Type', value: leave['leave_type'] ?? '—'),
                const SizedBox(width: 16),
                _DetailItem(icon: Icons.calendar_today_rounded, label: 'Period',
                    value: (fromDate.isNotEmpty && toDate.isNotEmpty) ? '$fromDate → $toDate' : '—'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _DetailItem(icon: Icons.timelapse_rounded, label: 'Days', value: days != null ? '$days day${days == 1 ? '' : 's'}' : '—'),
                const SizedBox(width: 16),
                if ((leave['replacement_name'] ?? '').toString().isNotEmpty)
                  _DetailItem(icon: Icons.swap_horiz_rounded, label: 'Replacement', value: leave['replacement_name'] ?? ''),
              ],
            ),
            if ((leave['reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.notes_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(leave['reason'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
                ],
              ),
            ],
            // Approve/Reject buttons for pending
            if (onApprove != null && onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                      label: const Text('Reject', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveBadge extends StatelessWidget {
  final String status;
  const _LeaveBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label;
    switch (status) {
      case 'approved': bg = AppColors.successLight; fg = AppColors.success;  label = 'Approved'; break;
      case 'rejected': bg = AppColors.errorLight;   fg = AppColors.error;    label = 'Rejected'; break;
      case 'pending':  bg = AppColors.warningLight; fg = AppColors.warning;  label = 'Pending';  break;
      default:         bg = AppColors.cardBorder;   fg = AppColors.textMuted; label = status;    break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  const _Chip({required this.label, required this.selected, required this.onTap, this.activeColor = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? activeColor : AppColors.inputBorder, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? activeColor : AppColors.textSecondary)),
      ),
    );
  }
}
