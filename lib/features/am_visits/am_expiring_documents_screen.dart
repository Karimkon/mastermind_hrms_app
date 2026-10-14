import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';

/// The documents behind the "Expiring Documents" figure on the dashboard.
///
/// That number existed only to prompt an action -- a work permit or contract
/// about to lapse -- and tapping it did nothing, so the only way to find out
/// which document it meant was to open staff one at a time.
///
/// Already-expired documents are listed first and marked. One that lapsed last
/// week matters more than one lapsing next month, and leaving it off the list
/// is how it stays unnoticed.
class AmExpiringDocumentsScreen extends ConsumerStatefulWidget {
  const AmExpiringDocumentsScreen({super.key});

  @override
  ConsumerState<AmExpiringDocumentsScreen> createState() =>
      _AmExpiringDocumentsScreenState();
}

class _AmExpiringDocumentsScreenState
    extends ConsumerState<AmExpiringDocumentsScreen> {
  List<Map<String, dynamic>> _docs = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;
  int _total = 0;
  int _expiredCount = 0;
  int _windowDays = 30;
  int? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await ApiService.get(
        ApiConstants.amExpiringDocuments,
        params: {
          'days': _windowDays,
          if (_selectedClientId != null) 'client_id': _selectedClientId,
        },
      );

      final body = Map<String, dynamic>.from(resp.data ?? const {});

      if (!mounted) return;

      setState(() {
        _docs = (body['data'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _clients = (body['clients'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _total = body['total'] ?? _docs.length;
        _expiredCount = body['expired_count'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load documents. Pull down to try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Expiring Documents'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Time window',
            icon: const Icon(Icons.filter_alt_outlined),
            onSelected: (d) {
              setState(() => _windowDays = d);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 30, child: Text('Next 30 days')),
              PopupMenuItem(value: 60, child: Text('Next 60 days')),
              PopupMenuItem(value: 90, child: Text('Next 90 days')),
              PopupMenuItem(value: 365, child: Text('Next 12 months')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _message(_error!, Icons.cloud_off_rounded)
                : Column(
                    children: [
                      _summary(),
                      if (_clients.length > 1) _clientFilter(),
                      Expanded(
                        child: _docs.isEmpty
                            ? _message(
                                'Nothing expiring in the next $_windowDays days.',
                                Icons.verified_rounded,
                              )
                            : ListView.separated(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(12),
                                itemCount: _docs.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) => _docTile(_docs[i]),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _summary() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _expiredCount > 0 ? AppColors.errorLight : AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _expiredCount > 0
                ? Icons.warning_amber_rounded
                : Icons.schedule_rounded,
            color: _expiredCount > 0 ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _expiredCount > 0
                  ? '$_total document${_total == 1 ? '' : 's'} need attention — $_expiredCount already expired'
                  : '$_total document${_total == 1 ? '' : 's'} expiring within $_windowDays days',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _expiredCount > 0 ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientFilter() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chip('All clients', _selectedClientId == null, () {
            setState(() => _selectedClientId = null);
            _load();
          }),
          ..._clients.map(
            (c) => _chip(
              '${c['name']}',
              _selectedClientId == c['id'],
              () {
                setState(() => _selectedClientId = c['id']);
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _docTile(Map<String, dynamic> d) {
    final expired = d['expired'] == true;
    final daysLeft = (d['days_left'] ?? 0) as int;

    final when = expired
        ? 'Expired ${daysLeft.abs()} day${daysLeft.abs() == 1 ? '' : 's'} ago'
        : daysLeft == 0
            ? 'Expires today'
            : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expired ? AppColors.error.withValues(alpha: 0.35) : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: expired ? AppColors.errorLight : AppColors.warningLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              expired ? Icons.error_outline_rounded : Icons.schedule_rounded,
              size: 20,
              color: expired ? AppColors.error : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d['title'] ?? 'Document'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${d['employee'] ?? ''} · ${d['company'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$when · ${d['expiry_date'] ?? ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: expired ? AppColors.error : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text, IconData icon) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
