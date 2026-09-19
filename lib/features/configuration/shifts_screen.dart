import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/configuration_provider.dart';

/// Working shifts and how much lateness each forgives.
///
/// Reading is open to anybody signed in, because a supervisor standing on site
/// should be able to check a grace period without ringing the office. The button
/// to add one appears only if the server says this person may.
class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(shiftsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: shifts.maybeWhen(
        data: (d) => d.canConfigure
            ? FloatingActionButton.extended(
                onPressed: () => _addShift(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New shift'),
              )
            : null,
        orElse: () => null,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shiftsProvider),
        child: shifts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Center(child: Text('Could not load shifts')),
            const SizedBox(height: 14),
            Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(shiftsProvider),
                child: const Text('Try again'),
              ),
            ),
          ]),
          data: (d) {
            if (d.items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.schedule_rounded, size: 46, color: AppColors.textMuted),
                SizedBox(height: 14),
                Center(
                  child: Text('No shifts defined',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Shifts decide when somebody counts as late.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ]);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: d.items.length,
              itemBuilder: (_, i) => _ShiftCard(d.items[i]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _addShift(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final grace = TextEditingController(text: '10');
    TimeOfDay? start;
    TimeOfDay? end;

    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New shift',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Name', hintText: 'Day, Night, Weekend',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  // A clock picker rather than a text field: a shift time typed
                  // as "8" or "8pm" is a validation error waiting to happen.
                  Expanded(
                    child: _TimeField(
                      label: 'Starts',
                      value: start == null ? null : fmt(start!),
                      onPick: () async {
                        final picked = await showTimePicker(
                            context: ctx, initialTime: start ?? const TimeOfDay(hour: 8, minute: 0));
                        if (picked != null) setSheet(() => start = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Ends',
                      value: end == null ? null : fmt(end!),
                      onPick: () async {
                        final picked = await showTimePicker(
                            context: ctx, initialTime: end ?? const TimeOfDay(hour: 17, minute: 0));
                        if (picked != null) setSheet(() => end = picked);
                      },
                    ),
                  ),
                ],
              ),
              if (start != null && end != null && fmt(end!).compareTo(fmt(start!)) < 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.infoLight, borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'This shift runs through midnight into the next day.',
                    style: TextStyle(fontSize: 12, color: AppColors.info),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: grace,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Grace period (minutes)',
                  helperText: 'Lateness forgiven before somebody counts as late',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (name.text.trim().isEmpty || start == null || end == null)
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Create shift'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(configurationActionsProvider.notifier).createShift(
          name: name.text.trim(),
          startTime: fmt(start!),
          endTime: fmt(end!),
          graceMinutes: int.tryParse(grace.text.trim()) ?? 0,
        );

    if (error == null) {
      ref.invalidate(shiftsProvider);
      messenger.showSnackBar(const SnackBar(
          content: Text('Shift created.'), backgroundColor: AppColors.success));
    } else {
      messenger.showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onPick;

  const _TimeField({required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(
          value ?? 'Pick',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: value == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final Map<String, dynamic> shift;

  const _ShiftCard(this.shift);

  @override
  Widget build(BuildContext context) {
    final grace = (shift['grace_minutes'] as num?)?.toInt() ?? 0;
    final overnight = shift['crosses_midnight'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: overnight ? const Color(0xFF1E293B) : AppColors.infoLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              overnight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              size: 20,
              color: overnight ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  '${shift['start_time'] ?? '—'} – ${shift['end_time'] ?? '—'}'
                  '${overnight ? ' (next day)' : ''}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(grace == 0 ? 'No grace' : '$grace min',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Text('grace',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
