import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/bsc_model.dart';
import '../../core/providers/bsc_provider.dart';

class BscMyAppraisalScreen extends ConsumerWidget {
  const BscMyAppraisalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appraisalAsync = ref.watch(bscMyAppraisalProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: appraisalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                e.toString().replaceFirst('Exception: ', ''),
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(bscMyAppraisalProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ]),
          ),
        ),
        data: (data) {
          if (data.cycle == null) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.balance_rounded, size: 48, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text('No active BSC cycle at the moment.', style: TextStyle(color: AppColors.textMuted)),
              ]),
            );
          }

          final perspectives = _groupByPerspective(data.kras);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bscMyAppraisalProvider),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              _CycleHeader(cycle: data.cycle!, overallScore: data.overallScore),
              const SizedBox(height: 20),
              ...perspectives.entries.map((entry) => _PerspectiveSection(
                    perspective: entry.key,
                    kras: entry.value,
                    onEdit: (kra, existing) => _showEditSheet(context, ref, kra, existing),
                  )),
            ]),
          );
        },
      ),
    );
  }

  Map<String, List<BscKraWithEntry>> _groupByPerspective(List<BscKraWithEntry> kras) {
    final map = <String, List<BscKraWithEntry>>{};
    for (final k in kras) {
      map.putIfAbsent(k.kra.perspective, () => []).add(k);
    }
    return map;
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, BscKraModel kra, BscEntryModel? entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EntryEditSheet(kra: kra, entry: entry, ref: ref),
    );
  }
}

class _CycleHeader extends StatelessWidget {
  final BscCycleModel cycle;
  final double overallScore;

  const _CycleHeader({required this.cycle, required this.overallScore});

  @override
  Widget build(BuildContext context) {
    final pct = (overallScore / 5.0).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.balance_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(cycle.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          Text('${cycle.period} · ${cycle.year}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(overallScore.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
            const Padding(padding: EdgeInsets.only(bottom: 6, left: 4), child: Text('/ 5.00', style: TextStyle(color: Colors.white70, fontSize: 14))),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white24,
              color: Colors.white,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('${(pct * 100).toStringAsFixed(0)}% of max score', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _PerspectiveSection extends StatelessWidget {
  final String perspective;
  final List<BscKraWithEntry> kras;
  final void Function(BscKraModel, BscEntryModel?) onEdit;

  const _PerspectiveSection({required this.perspective, required this.kras, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    const labels = {
      'financial':        'Financial',
      'customer':         'Customer',
      'internal_process': 'Internal Process',
      'learning_growth':  'Learning & Growth',
    };
    const colors = {
      'financial':        Colors.blue,
      'customer':         Colors.green,
      'internal_process': Colors.purple,
      'learning_growth':  Colors.orange,
    };

    final label = labels[perspective] ?? perspective;
    final color = colors[perspective] ?? AppColors.primary;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        ]),
      ),
      ...kras.map((k) => _KraEntryCard(item: k, onEdit: onEdit)),
      const SizedBox(height: 16),
    ]);
  }
}

class _KraEntryCard extends StatelessWidget {
  final BscKraWithEntry item;
  final void Function(BscKraModel, BscEntryModel?) onEdit;

  const _KraEntryCard({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final entry  = item.entry;
    final rating = entry?.rating;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.cardBorder)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(item.kra.kraName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            if (entry != null)
              _StatusBadge(status: entry.status)
            else
              const _StatusBadge(status: 'not_started'),
          ]),
          if (item.kra.objective != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(item.kra.objective!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 10),
          Row(children: [
            _InfoChip(label: 'Target', value: '${item.kra.target} ${item.kra.unit ?? ''}'),
            const SizedBox(width: 8),
            _InfoChip(label: 'Weight', value: '${item.kra.weightage}%'),
            if (entry?.actualAchieved != null) ...[
              const SizedBox(width: 8),
              _InfoChip(label: 'Achieved', value: '${entry!.actualAchieved}'),
            ],
            const Spacer(),
            if (rating != null) _StarRatingDisplay(rating: rating),
          ]),
          if (entry?.isDraft == true || entry == null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => onEdit(item.kra, entry),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _StarRatingDisplay extends StatelessWidget {
  final int rating;
  const _StarRatingDisplay({required this.rating});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
      size: 16,
      color: Colors.amber,
    )),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    const configs = {
      'draft':       (label: 'Draft',       bg: Color(0xFFFFF7ED), fg: Colors.orange),
      'submitted':   (label: 'Submitted',   bg: Color(0xFFEFF6FF), fg: Colors.blue),
      'approved':    (label: 'Approved',    bg: Color(0xFFECFDF5), fg: Colors.green),
      'not_started': (label: 'Not Started', bg: Color(0xFFF1F5F9), fg: Colors.grey),
    };
    final c = configs[status] ?? (label: status, bg: const Color(0xFFF1F5F9), fg: Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
      child: Text(c.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.fg as Color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.cardBorder)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
    ]),
  );
}

// ─── Edit Sheet ──────────────────────────────────────────────────────────────

class _EntryEditSheet extends ConsumerStatefulWidget {
  final BscKraModel kra;
  final BscEntryModel? entry;
  final WidgetRef ref;

  const _EntryEditSheet({required this.kra, this.entry, required this.ref});

  @override
  ConsumerState<_EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends ConsumerState<_EntryEditSheet> {
  late int _rating;
  late final TextEditingController _achievedCtrl;
  late final TextEditingController _commentCtrl;
  bool _saving    = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rating       = widget.entry?.rating ?? 0;
    _achievedCtrl = TextEditingController(text: widget.entry?.actualAchieved?.toString() ?? '');
    _commentCtrl  = TextEditingController(text: widget.entry?.employeeComment ?? '');
  }

  @override
  void dispose() {
    _achievedCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(widget.kra.kraName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        if (widget.kra.objective != null)
          Text(widget.kra.objective!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        // Achieved
        TextField(
          controller: _achievedCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Actual Achieved (Target: ${widget.kra.target} ${widget.kra.unit ?? ''})',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),

        // Rating
        const Text('Self Rating', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(5, (i) {
            final val = i + 1;
            return GestureDetector(
              onTap: () => setState(() => _rating = val),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  _rating >= val ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber, size: 36,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),

        // Comment
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Employee Comment',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),

        // Buttons
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Draft'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit'),
            ),
          ),
        ]),
      ]),
    );
  }

  Map<String, dynamic> _buildData() => {
    if (_achievedCtrl.text.isNotEmpty) 'actual_achieved': double.tryParse(_achievedCtrl.text),
    if (_rating > 0) 'rating': _rating,
    if (_commentCtrl.text.isNotEmpty) 'employee_comment': _commentCtrl.text,
  };

  Future<void> _save() async {
    if (widget.entry == null) { Navigator.pop(context); return; }
    setState(() => _saving = true);
    try {
      final msg = await ref.read(bscEntryProvider.notifier).updateEntry(widget.entry!.id, _buildData());
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (widget.entry == null) { Navigator.pop(context); return; }
    setState(() => _submitting = true);
    try {
      // Save first, then submit
      await ref.read(bscEntryProvider.notifier).updateEntry(widget.entry!.id, _buildData());
      final msg = await ref.read(bscEntryProvider.notifier).submitEntry(widget.entry!.id);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      setState(() => _submitting = false);
    }
  }
}
