import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/meeting_provider.dart';

class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {
  // Using empty string as stable key (no filters on this screen yet)
  static const String _paramsKey = '';

  @override
  Widget build(BuildContext context) {
    final meetingsAsync = ref.watch(meetingsProvider(_paramsKey));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Meetings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Meeting'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          meetingsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
            data: (meetings) {
              if (meetings.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No meetings scheduled', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return Column(children: meetings.map((m) => _MeetingCard(meeting: m, ref: ref)).toList());
            },
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _CreateMeetingDialog(ref: ref));
  }
}

class _MeetingCard extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final WidgetRef ref;
  const _MeetingCard({required this.meeting, required this.ref});

  @override
  Widget build(BuildContext context) {
    final rsvp = meeting['my_rsvp'] as String? ?? 'pending';
    final participants = (meeting['participants'] as List?)?.length ?? 0;

    final typeColors = {
      'board': [const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)],
      'one_on_one': [AppColors.success, AppColors.successLight],
      'training': [AppColors.warning, AppColors.warningLight],
      'team': [AppColors.primary, AppColors.infoLight],
    };
    final [fg, bg] = typeColors[meeting['type'] ?? 'team'] ?? [AppColors.primary, AppColors.infoLight];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.video_call_rounded, color: fg, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meeting['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(meeting['scheduled_at'] ?? meeting['date'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    const Icon(Icons.people_rounded, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('$participants participants', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                if (meeting['location'] != null || meeting['link'] != null) ...[
                  const SizedBox(height: 4),
                  Text(meeting['link'] ?? meeting['location'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  (meeting['type'] as String? ?? 'team').replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                  style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              // RSVP buttons
              if (rsvp == 'pending')
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(meetingActionsProvider.notifier).rsvp(meeting['id'] as int, 'accepted');
                        ref.invalidate(meetingsProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: AppColors.success),
                      ),
                      child: const Text('Accept', style: TextStyle(color: AppColors.success, fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(meetingActionsProvider.notifier).rsvp(meeting['id'] as int, 'declined');
                        ref.invalidate(meetingsProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Decline', style: TextStyle(color: AppColors.error, fontSize: 11)),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rsvp == 'accepted' ? AppColors.successLight : AppColors.errorLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rsvp == 'accepted' ? 'Accepted' : 'Declined',
                    style: TextStyle(color: rsvp == 'accepted' ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateMeetingDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _CreateMeetingDialog({required this.ref});

  @override
  ConsumerState<_CreateMeetingDialog> createState() => _CreateMeetingDialogState();
}

class _CreateMeetingDialogState extends ConsumerState<_CreateMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _agendaCtrl = TextEditingController();
  String _type = 'team';
  DateTime? _scheduledAt;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Meeting', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Meeting Title'), validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'team', child: Text('Team Meeting')),
                      DropdownMenuItem(value: 'one_on_one', child: Text('One-on-One')),
                      DropdownMenuItem(value: 'board', child: Text('Board Meeting')),
                      DropdownMenuItem(value: 'training', child: Text('Training Session')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'team'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                      if (d != null) setState(() => _scheduledAt = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text(_scheduledAt != null ? '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')}' : 'Select date'),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Location / Meeting Link')),
              const SizedBox(height: 12),
              TextFormField(controller: _agendaCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Agenda')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await widget.ref.read(meetingActionsProvider.notifier).createMeeting({
      'title': _titleCtrl.text,
      'type': _type,
      'location': _locationCtrl.text,
      'agenda': _agendaCtrl.text,
      if (_scheduledAt != null) 'scheduled_at': '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')}',
    });
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting created'), backgroundColor: AppColors.success));
        widget.ref.invalidate(meetingsProvider);
      }
    }
  }
}
