import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/driver_provider.dart';
import '../../core/services/location_disclosure.dart';
import '../../core/widgets/ui.dart';

/// The driver's day, and one button to add to it.
///
/// A stop is recorded where the driver stands, when they say so. Nothing runs
/// in the background and nothing is read while the app is closed — which is
/// both the honest design and the reason this needs no background-location
/// permission from Play.
///
/// The place names itself from the sites already pinned on the system, so
/// Sheraton, UNOC and Uganda Baati need no typing; only the genuinely new
/// places do.
class DriverScreen extends ConsumerWidget {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driverTodayProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('My journey')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logStop(context, ref),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('I have arrived'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(driverTodayProvider),
        child: async.when(
          loading: () => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpace.md),
                child: SkeletonBox(height: 84, radius: AppRadius.lg),
              ),
            ),
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: [
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load your journey',
                detail: e.toString().replaceFirst('Exception: ', ''),
                action: FilledButton(
                  onPressed: () => ref.invalidate(driverTodayProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
          data: (day) => day.stops.isEmpty
              ? ListView(
                  padding: EdgeInsets.all(AppSpace.page(context)),
                  children: const [
                    EmptyState(
                      icon: Icons.route_rounded,
                      title: 'No stops yet today',
                      detail: 'Press "I have arrived" wherever you stop. Known '
                          'places name themselves; for anywhere else, type the '
                          'name and what you went to do.',
                    ),
                  ],
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.page(context), AppSpace.page(context),
                    AppSpace.page(context), 96,
                  ),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Today',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(day.summary,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    for (final stop in day.stops) ...[
                      _StopCard(
                        stop: stop,
                        onDepart: stop.open
                            ? () async {
                                await DriverActions.depart(stop.id);
                                ref.invalidate(driverTodayProvider);
                              }
                            : null,
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _logStop(BuildContext context, WidgetRef ref) async {
    // Play rejects an app that goes straight to the system prompt, and the
    // wording has to say what is actually collected.
    if (!await LocationDisclosure.ensure(context,
        purpose: LocationDisclosure.driverStop)) {
      return;
    }

    if (!context.mounted) return;

    final result = await showModalBottomSheet<({String place, String purpose})>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ArrivedSheet(),
    );

    if (result == null || !context.mounted) return;

    final outcome = await DriverActions.arrive(
      placeName: result.place,
      purpose: result.purpose,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome.message),
        backgroundColor: outcome.ok ? AppColors.success : AppColors.error,
        duration: const Duration(seconds: 5),
      ),
    );

    if (outcome.ok) ref.invalidate(driverTodayProvider);
  }
}

class _ArrivedSheet extends StatefulWidget {
  const _ArrivedSheet();

  @override
  State<_ArrivedSheet> createState() => _ArrivedSheetState();
}

class _ArrivedSheetState extends State<_ArrivedSheet> {
  final _place = TextEditingController();
  final _purpose = TextEditingController();

  @override
  void dispose() {
    _place.dispose();
    _purpose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Where have you arrived?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Leave the name blank if it is a place the office already knows — '
            'it will fill itself in.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _place,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Place (only if it is somewhere new)',
              hintText: 'Church House',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purpose,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What did you go to do?',
              hintText: 'Collected documents',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                (place: _place.text, purpose: _purpose.text),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Log this stop'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final DriverStop stop;
  final VoidCallback? onDepart;

  const _StopCard({required this.stop, this.onDepart});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  stop.place,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ),
              if (stop.open)
                const AppChip(label: 'Still here', tone: AppColors.success),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (stop.arrivedAt != null) stop.arrivedAt!,
              if (stop.departedAt != null) '– ${stop.departedAt}',
              if (stop.minutes != null) '(${stop.minutes} min)',
            ].join(' '),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (stop.purpose != null && stop.purpose!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(stop.purpose!,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ],
          if (!stop.positionTrusted) ...[
            const SizedBox(height: 8),
            const AppChip(
              label: 'Position uncertain',
              tone: AppColors.warning,
              icon: Icons.gps_off_rounded,
            ),
          ],
          if (onDepart != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDepart,
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('I am leaving'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
