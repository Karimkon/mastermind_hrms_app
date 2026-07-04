import 'dart:math' show sqrt, sin, cos, atan2, pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/am_visit_model.dart';
import '../../core/providers/am_visit_provider.dart';

class AmVisitsScreen extends ConsumerStatefulWidget {
  const AmVisitsScreen({super.key});

  @override
  ConsumerState<AmVisitsScreen> createState() => _AmVisitsScreenState();
}

class _AmVisitsScreenState extends ConsumerState<AmVisitsScreen> {
  int? _selectedClientId;
  bool _clockingIn = false;
  bool _clockingOut = false;
  String? _locError;
  final _notesCtrl = TextEditingController();

  // Location state
  double? _currentLat;
  double? _currentLng;
  double? _distanceToClient;
  bool _fetchingLocation = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(amVisitProvider);
    final activeAsync = ref.watch(amVisitActiveProvider);
    final clientsAsync = ref.watch(amVisitClientsProvider);

    // Daily summary computed from loaded history (no extra API call)
    final todaySummary = historyAsync.valueOrNull != null
        ? _computeTodaySummary(historyAsync.value!.items)
        : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(amVisitActiveProvider);
          ref.invalidate(amVisitClientsProvider);
          await ref.read(amVisitProvider.notifier).refresh();
          if (clientsAsync.hasValue) _fetchCurrentLocation(clientsAsync.value!);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Today's summary ──────────────────────────────────────────────
            if (todaySummary != null) ...[
              _SectionTitle("Today's Activity"),
              const SizedBox(height: 12),
              _TodaySummaryCard(summary: todaySummary),
              const SizedBox(height: 24),
            ],

            // ── Active sessions ──────────────────────────────────────────────
            _SectionTitle('Active Sessions'),
            const SizedBox(height: 12),
            activeAsync.when(
              loading: () => const _ShimmerCard(),
              error: (e, _) => _ErrorCard('$e'),
              data: (sessions) => sessions.isEmpty
                  ? const _EmptyCard(
                      icon: Icons.location_off_rounded,
                      message: 'No active sessions today')
                  : Column(
                      children: sessions
                          .map((s) => _ActiveSessionCard(
                                session: s,
                                onClockOut: _doClockOut,
                                isLoading: _clockingOut,
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 24),

            // ── Clock-in panel ───────────────────────────────────────────────
            _SectionTitle('Clock In at Client Site'),
            const SizedBox(height: 12),
            clientsAsync.when(
              loading: () => const _ShimmerCard(),
              error: (e, _) => _ErrorCard('$e'),
              data: (clients) {
                // Silently fetch location once when client list is ready
                if (_currentLat == null && !_fetchingLocation) {
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _fetchCurrentLocation(clients));
                }
                if (clients.isEmpty) {
                  return const _EmptyCard(
                      icon: Icons.business_center_rounded,
                      message: 'No clients assigned to you');
                }
                final selected = _selectedClientId != null
                    ? clients.firstWhere((c) => c.id == _selectedClientId,
                        orElse: () => clients.first)
                    : null;
                return _ClockInCard(
                  clients: clients,
                  selectedClientId: _selectedClientId,
                  selectedClient: selected,
                  onClientSelected: (id) {
                    setState(() {
                      _selectedClientId = id;
                      _updateDistance(clients);
                    });
                  },
                  onClockIn: _doClockIn,
                  isLoading: _clockingIn || _fetchingLocation,
                  locError: _locError,
                  notesCtrl: _notesCtrl,
                  distanceMetres: _distanceToClient,
                );
              },
            ),
            const SizedBox(height: 24),

            // ── History ──────────────────────────────────────────────────────
            _SectionTitle('Visit History'),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const _ShimmerCard(),
              error: (e, _) => _ErrorCard('$e'),
              data: (state) => state.items.isEmpty
                  ? const _EmptyCard(
                      icon: Icons.history_rounded,
                      message: 'No visit history yet')
                  : Column(
                      children:
                          state.items.map((s) => _HistoryCard(session: s)).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _computeTodaySummary(List<AmVisitSessionModel> items) {
    final today = DateTime.now();
    final todayItems = items
        .where((s) =>
            s.clockedInAt.year == today.year &&
            s.clockedInAt.month == today.month &&
            s.clockedInAt.day == today.day)
        .toList();
    if (todayItems.isEmpty) return null;

    double totalHours = 0;
    int activeCount = 0;
    int completedCount = 0;
    final clients = <String>{};

    for (final s in todayItems) {
      clients.add(s.clientName);
      if (s.isActive) {
        activeCount++;
      } else {
        completedCount++;
        totalHours += s.durationHours ?? 0;
      }
    }
    return {
      'total_sessions': todayItems.length,
      'active_count': activeCount,
      'completed_count': completedCount,
      'total_hours': totalHours,
      'clients': clients.toList(),
    };
  }

  Future<void> _fetchCurrentLocation(List<AmVisitClientModel> clients) async {
    if (_fetchingLocation) return;
    if (mounted) setState(() => _fetchingLocation = true);
    try {
      final pos = await _getLocation();
      if (mounted) {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        _updateDistance(clients);
      }
    } catch (_) {
      // Silently fail — user will see "Fetching your location..." until retry
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  void _updateDistance(List<AmVisitClientModel> clients) {
    if (_selectedClientId == null || _currentLat == null || _currentLng == null) {
      _distanceToClient = null;
      return;
    }
    final client =
        clients.firstWhere((c) => c.id == _selectedClientId, orElse: () => clients.first);
    if (client.workSiteLat != null && client.workSiteLng != null) {
      _distanceToClient = _haversineDistance(
        _currentLat!, _currentLng!,
        client.workSiteLat!, client.workSiteLng!,
      );
    } else {
      _distanceToClient = null;
    }
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dphi = (lat2 - lat1) * pi / 180;
    final dlambda = (lon2 - lon1) * pi / 180;
    final a = sin(dphi / 2) * sin(dphi / 2) +
        cos(phi1) * cos(phi2) * sin(dlambda / 2) * sin(dlambda / 2);
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  // ─── Clock-in ─────────────────────────────────────────────────────────────

  Future<void> _doClockIn() async {
    if (_selectedClientId == null) {
      _showSnack('Please select a client first.', isError: true);
      return;
    }
    setState(() { _clockingIn = true; _locError = null; });
    try {
      Position pos;
      try {
        pos = await _getLocation();
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
      } catch (e) {
        setState(() { _locError = '$e'; _clockingIn = false; });
        _showSnack('$e', isError: true);
        return;
      }
      final notes = _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      final msg = await ref.read(amVisitProvider.notifier).clockIn(
        clientId: _selectedClientId!,
        lat: pos.latitude,
        lng: pos.longitude,
        notes: notes,
      );
      ref.invalidate(amVisitActiveProvider);
      setState(() { _selectedClientId = null; _distanceToClient = null; });
      _notesCtrl.clear();
      if (mounted) _showSnack(msg);
    } catch (e) {
      if (mounted) _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _clockingIn = false);
    }
  }

  // ─── Clock-out ────────────────────────────────────────────────────────────

  Future<void> _doClockOut(int sessionId) async {
    final notes = await _showClockOutDialog();
    if (notes == null) return; // user cancelled

    setState(() => _clockingOut = true);
    try {
      Position? pos;
      try { pos = await _getLocation(); } catch (_) {}
      final msg = await ref.read(amVisitProvider.notifier).clockOut(
        sessionId: sessionId,
        lat: pos?.latitude,
        lng: pos?.longitude,
        notes: notes.trim().isNotEmpty ? notes.trim() : null,
      );
      ref.invalidate(amVisitActiveProvider);
      if (mounted) _showSnack(msg);
    } catch (e) {
      if (mounted) _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _clockingOut = false);
    }
  }

  Future<String?> _showClockOutDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clock Out', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: false,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Summary of tasks completed...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clock Out'),
          ),
        ],
      ),
    );
  }

  // ─── Location ─────────────────────────────────────────────────────────────

  Future<Position> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Enable GPS and try again.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable in Settings.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ─── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
}

// ─── Today's summary card ─────────────────────────────────────────────────────

class _TodaySummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _TodaySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalHours = (summary['total_hours'] as double);
    final h = totalHours.floor();
    final m = ((totalHours - h) * 60).round();
    final clients = (summary['clients'] as List).cast<String>();
    final activeCount = summary['active_count'] as int;
    final completedCount = summary['completed_count'] as int;

    return Card(
      elevation: 0,
      color: AppColors.infoLight,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.primary)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.today_rounded, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13),
            ),
            const Spacer(),
            if (activeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.success, borderRadius: BorderRadius.circular(12)),
                child: Text('$activeCount active',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _StatChip(Icons.access_time_rounded, '${h}h ${m}m logged', AppColors.primary),
            const SizedBox(width: 8),
            _StatChip(Icons.business_rounded,
                '${clients.length} client${clients.length == 1 ? '' : 's'}', AppColors.info),
            const SizedBox(width: 8),
            _StatChip(Icons.check_circle_rounded, '$completedCount done', AppColors.success),
          ]),
          if (clients.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: clients
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(c,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ─── Clock-in card ────────────────────────────────────────────────────────────

class _ClockInCard extends StatelessWidget {
  final List<AmVisitClientModel> clients;
  final int? selectedClientId;
  final AmVisitClientModel? selectedClient;
  final void Function(int) onClientSelected;
  final VoidCallback onClockIn;
  final bool isLoading;
  final String? locError;
  final TextEditingController notesCtrl;
  final double? distanceMetres;

  const _ClockInCard({
    required this.clients,
    this.selectedClientId,
    this.selectedClient,
    required this.onClientSelected,
    required this.onClockIn,
    required this.isLoading,
    this.locError,
    required this.notesCtrl,
    this.distanceMetres,
  });

  @override
  Widget build(BuildContext context) {
    final radius = selectedClient?.geoFenceRadius ?? 100;
    final hasCoords = selectedClient?.workSiteLat != null;
    final withinFence = distanceMetres != null && distanceMetres! <= radius;
    final outsideFence = distanceMetres != null && distanceMetres! > radius;

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Client dropdown
          const Text('Select Client',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: selectedClientId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text('Choose a client site'),
            items: clients
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.companyName)))
                .toList(),
            onChanged: (v) { if (v != null) onClientSelected(v); },
          ),

          // Work site address + geo-fence badge
          if (selectedClient?.workSiteAddress != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(selectedClient!.workSiteAddress!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.infoLight, borderRadius: BorderRadius.circular(12)),
                child: Text('${radius}m geo-fence',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary)),
              ),
            ]),
          ],

          // Distance / geo-fence status indicator
          if (selectedClient != null && hasCoords) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: distanceMetres == null
                    ? AppColors.warningLight
                    : withinFence
                        ? AppColors.successLight
                        : AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(
                  distanceMetres == null
                      ? Icons.gps_not_fixed_rounded
                      : withinFence
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_off_rounded,
                  size: 16,
                  color: distanceMetres == null
                      ? AppColors.warning
                      : withinFence
                          ? AppColors.success
                          : AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    distanceMetres == null
                        ? 'Fetching your location...'
                        : withinFence
                            ? 'Within geo-fence · ${distanceMetres!.round()}m from site'
                            : 'Outside geo-fence · ${distanceMetres!.round()}m from site (limit: ${radius}m)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: distanceMetres == null
                          ? AppColors.warning
                          : withinFence
                              ? AppColors.success
                              : AppColors.error,
                    ),
                  ),
                ),
              ]),
            ),
          ],

          if (locError != null) ...[
            const SizedBox(height: 8),
            Text(locError!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
          ],

          // Notes field
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Visit notes (optional)',
              hintText: 'Purpose of visit, tasks to complete...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onClockIn,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded, size: 18),
              label: Text(isLoading ? 'Getting location...' : 'Clock In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: outsideFence ? AppColors.warning : AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          if (outsideFence) ...[
            const SizedBox(height: 6),
            const Text(
              'You are outside the geo-fence. Your location will be recorded for review.',
              style: TextStyle(fontSize: 11, color: AppColors.warning),
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Active session card ──────────────────────────────────────────────────────

class _ActiveSessionCard extends StatelessWidget {
  final AmVisitSessionModel session;
  final void Function(int) onClockOut;
  final bool isLoading;

  const _ActiveSessionCard(
      {required this.session, required this.onClockOut, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(session.clockedInAt);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFECFDF5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF86EFAC))),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.clientName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                  'In since ${DateFormat('HH:mm').format(session.clockedInAt)} · ${h}h ${m}m elapsed',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (session.siteAddress != null)
                Text(session.siteAddress!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(session.notes!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isLoading ? null : () => onClockOut(session.id),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Clock Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── History card ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final AmVisitSessionModel session;
  const _HistoryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.cardBorder)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor:
                session.isActive ? AppColors.success : AppColors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.business_rounded,
                color: session.isActive ? Colors.white : AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.clientName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(
                '${DateFormat('d MMM y').format(session.clockedInAt)}  ·  '
                '${DateFormat('HH:mm').format(session.clockedInAt)}'
                '${session.clockedOutAt != null ? ' – ${DateFormat('HH:mm').format(session.clockedOutAt!)}' : ' (active)'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(session.notes!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          session.durationHours != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.infoLight, borderRadius: BorderRadius.circular(8)),
                  child: Text(session.formattedDuration,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                )
              : const Text('Active',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Utility widgets ──────────────────────────────────────────────────────────

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();
  @override
  Widget build(BuildContext context) => Container(
      height: 80,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)));
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);
  @override
  Widget build(BuildContext context) => Card(
      color: const Color(0xFFFEF2F2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $message',
              style: const TextStyle(color: AppColors.error, fontSize: 13))));
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.cardBorder)),
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            Icon(icon, color: AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Text(message,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ])));
}
