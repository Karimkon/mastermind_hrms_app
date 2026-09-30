import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/change_approval_model.dart';
import '../../core/providers/change_approvals_provider.dart';

/// HR's queue of changes account managers have proposed.
///
/// Nothing in this queue has happened. Each row is a proposal against a live
/// record, and the decision needs the field-by-field diff — so the list opens
/// straight into it rather than asking somebody to approve a summary line.
class ChangeApprovalsScreen extends ConsumerStatefulWidget {
  const ChangeApprovalsScreen({super.key});

  @override
  ConsumerState<ChangeApprovalsScreen> createState() => _ChangeApprovalsScreenState();
}

class _ChangeApprovalsScreenState extends ConsumerState<ChangeApprovalsScreen> {
  String _status = 'pending';

  static const _tabs = [
    (label: 'Pending', value: 'pending'),
    (label: 'Approved', value: 'approved'),
    (label: 'Rejected', value: 'rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(changeApprovalsProvider(_status));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: _tabs.map((t) {
              final active = _status == t.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.label),
                  selected: active,
                  onSelected: (_) => setState(() => _status = t.value),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(
              message: e.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(changeApprovalsProvider(_status)),
            ),
            data: (data) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(changeApprovalsProvider(_status)),
              child: data.changes.isEmpty
                  ? _EmptyState(status: _status)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: data.changes
                          .map((c) => _ChangeCard(
                                change: c,
                                onOpen: () => _openChange(context, c.id),
                              ))
                          .toList(),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  void _openChange(BuildContext context, int id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChangeDetailSheet(id: id),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final ChangeApprovalModel change;
  final VoidCallback onOpen;
  const _ChangeCard({required this.change, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(change.subjectLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            _StatusChip(status: change.status),
          ]),
          const SizedBox(height: 6),
          Text(
            '${change.fieldCount} field${change.fieldCount == 1 ? '' : 's'} '
            '· ${change.action} · ${change.modelType}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 4, children: [
            if (change.requestedBy != null)
              _Meta(icon: Icons.person_rounded, text: change.requestedBy!),
            if (change.client != null)
              _Meta(icon: Icons.business_rounded, text: change.client!),
            if (change.createdAt != null)
              _Meta(icon: Icons.schedule_rounded, text: change.createdAt!),
          ]),
        ]),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (colour, label) = switch (status) {
      'approved' => (const Color(0xFF16A34A), 'Approved'),
      'rejected' => (const Color(0xFFDC2626), 'Rejected'),
      _ => (const Color(0xFFCA8A04), 'Pending'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colour)),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      ]);
}

// ── The decision ────────────────────────────────────────────────────────────

class _ChangeDetailSheet extends ConsumerStatefulWidget {
  final int id;
  const _ChangeDetailSheet({required this.id});

  @override
  ConsumerState<_ChangeDetailSheet> createState() => _ChangeDetailSheetState();
}

class _ChangeDetailSheetState extends ConsumerState<_ChangeDetailSheet> {
  bool _busy = false;

  Future<void> _act(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _approve(ChangeApprovalModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply this change?'),
        content: Text(
          c.hasDrift
              ? 'Somebody has edited this record since the change was proposed. '
                'Approving will overwrite what is there now.'
              : 'The proposed values will be written to ${c.subjectLabel}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _act(() => ref.read(changeApprovalActionsProvider).approve(widget.id));
  }

  Future<void> _reject() async {
    final controller = TextEditingController();

    // Required, not optional: a refusal with no reason leaves the account
    // manager guessing and resubmitting the same thing.
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this change'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Why?',
            hintText: 'So the account manager knows what to correct.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (note == null || note.isEmpty) return;
    await _act(() => ref.read(changeApprovalActionsProvider).reject(widget.id, note));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(changeApprovalProvider(widget.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(e.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        data: (c) => Column(children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                Text(c.subjectLabel,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Proposed by ${c.requestedBy ?? 'somebody'}'
                  '${c.createdAt != null ? ' · ${c.createdAt}' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),

                if (c.subjectGone) ...[
                  const SizedBox(height: 12),
                  const _Notice(
                    tone: Color(0xFFDC2626),
                    icon: Icons.error_outline_rounded,
                    text: 'The record this change refers to no longer exists.',
                  ),
                ] else if (c.hasDrift) ...[
                  const SizedBox(height: 12),
                  const _Notice(
                    tone: Color(0xFFCA8A04),
                    icon: Icons.warning_amber_rounded,
                    text: 'Somebody has edited this record since the change was proposed. '
                        'The fields marked below would be overwritten.',
                  ),
                ],

                const SizedBox(height: 16),
                ...c.diff.map((row) => _DiffRow(row: row)),

                if (c.reviewNote != null && c.reviewNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    tone: const Color(0xFF475569),
                    icon: Icons.notes_rounded,
                    text: 'Note: ${c.reviewNote}',
                  ),
                ],
              ],
            ),
          ),

          if (c.isPending)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _reject,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || c.subjectGone ? null : () => _approve(c),
                      icon: _busy
                          ? const SizedBox(
                              width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final ChangeDiffRow row;
  const _DiffRow({required this.row});

  @override
  Widget build(BuildContext context) {
    const empty = '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: row.drifted ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: row.drifted ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(row.label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          if (row.drifted)
            const Text('changed since',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Now', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              Text(row.current ?? empty,
                  style: const TextStyle(fontSize: 13, decoration: TextDecoration.lineThrough)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.textMuted),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Would become',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              Text(row.proposed ?? empty,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  final Color tone;
  final IconData icon;
  final String text;
  const _Notice({required this.tone, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tone.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: tone, height: 1.35)),
          ),
        ]),
      );
}

// ── States ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(status == 'pending' ? Icons.inbox_rounded : Icons.history_rounded,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            status == 'pending' ? 'Nothing waiting' : 'Nothing here',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            status == 'pending'
                ? 'Changes account managers propose to employee records land here for your approval.'
                : 'No changes have been $status yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}
