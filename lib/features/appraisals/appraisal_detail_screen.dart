import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/appraisal_provider.dart';
import '../../widgets/status_badge.dart';

/// One appraisal card, and the one thing this person can do with it.
///
/// The card is read-only until the server says otherwise. `your_move` decides
/// which action bar appears at the bottom — scoring for the appraiser, confirm
/// or send back for the manager, sign-off for the employee — and when it is null
/// there is no action bar at all rather than a disabled button that invites a tap
/// and then refuses it.
class AppraisalDetailScreen extends ConsumerStatefulWidget {
  final int appraisalId;

  const AppraisalDetailScreen({super.key, required this.appraisalId});

  @override
  ConsumerState<AppraisalDetailScreen> createState() => _AppraisalDetailScreenState();
}

class _AppraisalDetailScreenState extends ConsumerState<AppraisalDetailScreen> {
  /// Edits held locally until saved, keyed by KPI id.
  ///
  /// Only touched rows are sent. Posting every KPI back would overwrite a
  /// colleague's concurrent edit with a value this screen merely displayed.
  final Map<int, Map<String, dynamic>> _edits = {};

  bool _busy = false;

  Future<void> _run(Future<bool> Function() action, String success) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      _edits.clear();
      ref.invalidate(appraisalDetailProvider(widget.appraisalId));
      ref.invalidate(appraisalsProvider);
      messenger.showSnackBar(
          SnackBar(content: Text(success), backgroundColor: AppColors.success));
    } else {
      // The server's refusals are meaningful here — "3 KPIs still have no
      // rating", "this appraisal is not with you" — so say something is wrong
      // rather than failing silently.
      final err = ref.read(appraisalActionsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(_message(err)),
        backgroundColor: AppColors.error,
      ));
    }
  }

  String _message(AsyncValue<void> state) {
    final error = state is AsyncError ? state.error : null;
    final text = error?.toString() ?? '';
    // Dio wraps the body; the useful sentence is the server's `message`.
    final match = RegExp(r'"message":"([^"]+)"').firstMatch(text);
    return match?.group(1) ?? 'That could not be saved. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(appraisalDetailProvider(widget.appraisalId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Appraisal'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: card.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text('This appraisal could not be opened.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('It may not be yours to read.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(appraisalDetailProvider(widget.appraisalId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (a) => _body(a),
      ),
    );
  }

  Widget _body(Map<String, dynamic> a) {
    final move = a['your_move'] as String?;
    final kpis = List<Map<String, dynamic>>.from(a['kpis'] ?? []);
    final canScore = move == 'score';
    // The employee's own turn, before anybody rates them: the same rows, a
    // different author, a different field.
    final canSelfAssess = move == 'self_assess';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _header(a),
              const SizedBox(height: 18),
              if (kpis.isEmpty)
                _note('No KPIs have been set for this card yet. HR sets them in the '
                    'browser, where the weights can be balanced to 100%.')
              else ...[
                const _Label('Key result areas'),
                const SizedBox(height: 8),
                ...kpis.map((k) => _KpiTile(
                      kpi: k,
                      editable: canScore,
                      selfAssessing: canSelfAssess,
                      draft: _edits[k['id'] as int],
                      onChanged: (field, value) {
                        setState(() {
                          final id = k['id'] as int;
                          _edits.putIfAbsent(
                              id,
                              () => canSelfAssess
                                  ? {
                                      'actual_achieved': k['actual_achieved'],
                                      'self_rating': k['self_rating'],
                                      'self_note': k['self_note'],
                                    }
                                  : {
                                      'actual_achieved': k['actual_achieved'],
                                      'rating': k['rating'],
                                      'evidence_note': k['evidence_note'],
                                    });
                          _edits[id]![field] = value;
                        });
                      },
                    )),
              ],
              if ((a['manager_comment'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 18),
                const _Label("Manager's comment"),
                const SizedBox(height: 6),
                _quote(a['manager_comment'].toString()),
              ],
              if ((a['employee_comment'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 18),
                const _Label("Employee's comment"),
                const SizedBox(height: 6),
                _quote(a['employee_comment'].toString()),
              ],
              const SizedBox(height: 18),
              _history(List<Map<String, dynamic>>.from(a['history'] ?? [])),
            ],
          ),
        ),
        if (move != null) _actionBar(a, move, kpis),
      ],
    );
  }

  Widget _header(Map<String, dynamic> a) {
    final percent = (a['overall_percent'] as num?)?.toDouble();
    final unrated = (a['unrated_count'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a['employee_name']?.toString() ?? 'Unnamed employee',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              StatusBadge(a['status']?.toString() ?? 'draft'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [a['title'], a['period'], a['year']?.toString()]
                .where((s) => s != null && s.toString().isNotEmpty)
                .join(' · '),
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          if (a['appraiser_name'] != null) ...[
            const SizedBox(height: 2),
            Text('Appraiser: ${a['appraiser_name']}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 14),
          // Only a fully rated card gets a headline percentage. A number derived
          // from a subset of the weights looks like a result and is not one.
          if (percent != null && unrated == 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${percent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(a['band_label']?.toString() ?? '',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              ],
            )
          else
            Text(
              '$unrated of ${a['kpi_count']} KPIs still to rate',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning),
            ),
        ],
      ),
    );
  }

  Widget _actionBar(Map<String, dynamic> a, String move, List<Map<String, dynamic>> kpis) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: switch (move) {
        'self_assess' => Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || _edits.isEmpty ? null : _saveSelfAssessment,
                  child: Text(_edits.isEmpty ? 'No changes' : 'Save progress'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _submitSelfAssessment(a, kpis),
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        'score' => Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || _edits.isEmpty ? null : _saveScores,
                  child: Text(_edits.isEmpty ? 'No changes' : 'Save scores'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _returnToManager(a),
                  child: const Text('Return to manager'),
                ),
              ),
            ],
          ),
        'confirm' => Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: _busy ? null : _sendBack,
                  child: const Text('Send back'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _confirm,
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        'self_appraise' => SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _signOff,
              child: const Text('Add my comments and sign off'),
            ),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // ── actions ────────────────────────────────────────────────────────────

  Future<void> _saveSelfAssessment() async {
    await _run(
      () => ref
          .read(appraisalActionsProvider.notifier)
          .saveSelfAssessment(widget.appraisalId, _edits),
      'Saved. You can come back to this before submitting.',
    );
  }

  /// Submitting is one-way, so the state of the card is stated before the tap
  /// rather than refused after it.
  Future<void> _submitSelfAssessment(
      Map<String, dynamic> a, List<Map<String, dynamic>> kpis) async {
    // Counted from the card plus anything typed but not yet saved, so the
    // warning matches what the person is looking at.
    final unrated = kpis.where((k) {
      final draft = _edits[k['id'] as int];
      final rating = draft != null && draft.containsKey('self_rating')
          ? draft['self_rating']
          : k['self_rating'];
      return rating == null;
    }).length;

    if (unrated > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$unrated of ${kpis.length} still need a self-rating.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send this for scoring?'),
        content: Text(
          'It goes to ${a['appraiser_name'] ?? 'your appraiser'}, and you will not be '
          'able to change it afterwards. You will see it again at the end to read '
          'the final ratings and sign it off.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );

    if (ok != true) return;

    // Saved first: anything typed since the last save would otherwise be lost
    // the moment the card leaves their hands.
    if (_edits.isNotEmpty) {
      setState(() => _busy = true);
      final saved = await ref
          .read(appraisalActionsProvider.notifier)
          .saveSelfAssessment(widget.appraisalId, _edits);
      if (!mounted) return;
      setState(() => _busy = false);

      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your last changes, so nothing was submitted.'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }

    await _run(
      () => ref
          .read(appraisalActionsProvider.notifier)
          .submitSelfAssessment(widget.appraisalId),
      'Submitted. Your appraiser will score it next.',
    );
  }

  Future<void> _saveScores() async {
    await _run(
      () => ref.read(appraisalActionsProvider.notifier).score(widget.appraisalId, _edits),
      'Scores saved.',
    );
  }

  Future<void> _returnToManager(Map<String, dynamic> a) async {
    final comment = await _askForText(
      title: 'Return to manager',
      hint: 'Anything they should know (optional)',
      confirmLabel: 'Return',
      required: false,
    );
    if (comment == null) return;

    // The manager is whoever the card already names; the phone does not offer a
    // people-picker, because choosing the wrong person here is hard to undo.
    final returnTo = a['return_to_id'] ?? a['initiated_by'];
    if (returnTo == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This card has no manager set. Return it from the browser.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    await _run(
      () => ref
          .read(appraisalActionsProvider.notifier)
          .returnToManager(widget.appraisalId, returnTo as int, comment),
      'Returned to the manager.',
    );
  }

  Future<void> _confirm() async {
    final comment = await _askForText(
      title: 'Confirm appraisal',
      hint: 'Your comment (optional)',
      confirmLabel: 'Confirm',
      required: false,
    );
    if (comment == null) return;

    await _run(
      () => ref.read(appraisalActionsProvider.notifier).confirm(widget.appraisalId, comment),
      'Confirmed and sent to the employee.',
    );
  }

  Future<void> _sendBack() async {
    final comment = await _askForText(
      title: 'Send back to the appraiser',
      hint: 'What needs another look?',
      confirmLabel: 'Send back',
      required: true,
    );
    if (comment == null || comment.isEmpty) return;

    await _run(
      () => ref.read(appraisalActionsProvider.notifier).sendBack(widget.appraisalId, comment),
      'Sent back to the appraiser.',
    );
  }

  Future<void> _signOff() async {
    final comment = await _askForText(
      title: 'Your comments',
      hint: 'How you see this review',
      confirmLabel: 'Sign off',
      required: true,
    );
    if (comment == null || comment.isEmpty) return;

    await _run(
      () => ref.read(appraisalActionsProvider.notifier).selfAppraise(widget.appraisalId, comment),
      'Thank you — your appraisal is complete.',
    );
  }

  /// Returns null if dismissed, so "cancelled" and "left blank" stay different.
  Future<String?> _askForText({
    required String title,
    required String hint,
    required String confirmLabel,
    required bool required,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ── small pieces ───────────────────────────────────────────────────────

  Widget _note(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
      );

  Widget _quote(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45)),
      );

  Widget _history(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('History'),
        const SizedBox(height: 8),
        ...history.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 5, right: 10),
                    decoration: const BoxDecoration(
                        color: AppColors.textMuted, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${h['event']?.toString().replaceAll('_', ' ') ?? ''} → ${h['to_status']?.toString().replaceAll('_', ' ') ?? ''}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        if ((h['comment'] ?? '').toString().isNotEmpty)
                          Text(h['comment'].toString(),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        Text(h['at']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      );
}

/// One key result area: what was asked for, and what actually happened.
class _KpiTile extends StatelessWidget {
  final Map<String, dynamic> kpi;
  final bool editable;
  final bool selfAssessing;
  final Map<String, dynamic>? draft;
  final void Function(String field, dynamic value) onChanged;

  const _KpiTile({
    required this.kpi,
    required this.editable,
    this.selfAssessing = false,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Which field this row writes depends on whose turn it is. The employee
    // writes self_rating, the appraiser writes rating; they never share one.
    final field = selfAssessing ? 'self_rating' : 'rating';
    final rating = (draft?[field] ?? kpi[field]) as int?;
    final actual = (draft?['actual_achieved'] ?? kpi['actual_achieved'])?.toString() ?? '';
    final selfRating = kpi['self_rating'] as int?;
    final selfNote = (kpi['self_note'] ?? '').toString();
    final open = editable || selfAssessing;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rating == null && open ? AppColors.warning.withValues(alpha: 0.5) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kpi['kra_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text('${(kpi['weightage'] as num?)?.toStringAsFixed(0) ?? '0'}%',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ],
          ),
          if ((kpi['performance_measure'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(kpi['performance_measure'].toString(),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _pill('Target', kpi['target']?.toString() ?? '—'),
              const SizedBox(width: 8),
              if (!open) _pill('Actual', actual.isEmpty ? '—' : actual),
              // Put in front of the appraiser while they score, so they rate
              // with the employee's own account in view rather than after it.
              if (editable && selfRating != null) ...[
                const SizedBox(width: 8),
                _pill('Self-rated', '$selfRating'),
              ],
            ],
          ),
          if (editable && selfNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“$selfNote”',
                style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          ],
          if (open) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: actual,
              decoration: const InputDecoration(
                labelText: 'Actual achieved',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => onChanged('actual_achieved', v),
            ),
            if (selfAssessing) ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: selfNote,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Anything worth saying about this',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => onChanged('self_note', v),
              ),
            ],
            const SizedBox(height: 12),
            Text(selfAssessing ? 'Your rating' : 'Rating',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            // Five taps, not a dropdown. Rating is the single most repeated
            // action on this screen and it should cost one touch.
            Row(
              children: List.generate(5, (i) {
                final value = i + 1;
                final selected = rating == value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 4 ? 0 : 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onChanged(field, value),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: selected ? AppColors.primary : AppColors.inputBorder),
                        ),
                        child: Text('$value',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : AppColors.textSecondary,
                            )),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ] else if (rating != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: i < rating ? AppColors.warning : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                // Where the two disagree by more than a point, say so. That gap
                // is the conversation, not an error to reconcile quietly.
                if (selfRating != null && (selfRating - rating).abs() > 1) ...[
                  Text('self-rated $selfRating',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning)),
                  const SizedBox(width: 8),
                ],
                if (kpi['weighted_index'] != null)
                  Text('index ${(kpi['weighted_index'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$label: $value',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}
