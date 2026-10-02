import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/careers_model.dart';
import '../../core/providers/careers_provider.dart';
import '../../core/services/careers_api.dart';

/// The application form, as a sheet over the job.
///
/// The CV is required and everything else is not. That is deliberate: an
/// applicant on a phone in Mbale may not have a scanned police letter to
/// hand, and an application that cannot be submitted is worse for everybody
/// than one missing an attachment a recruiter can ask for later.
class ApplyForm extends ConsumerStatefulWidget {
  final CareerJob job;
  final List<DocumentSlot> slots;
  final List<ScreeningQuestion> questions;

  const ApplyForm({
    super.key,
    required this.job,
    required this.slots,
    required this.questions,
  });

  @override
  ConsumerState<ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends ConsumerState<ApplyForm> {
  final _coverLetter = TextEditingController();

  /// Chosen files, by document type. A type that takes several holds several.
  final Map<String, List<PlatformFile>> _picked = {};

  /// Screening answers, by question id.
  final Map<int, String> _answers = {};

  bool _sending = false;
  double _progress = 0;
  String? _error;

  @override
  void dispose() {
    _coverLetter.dispose();
    super.dispose();
  }

  List<String> _extensionsFor(String type) =>
      type == 'passport_photo' ? ['jpg', 'jpeg', 'png'] : ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];

  Future<void> _pick(DocumentSlot slot) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: slot.multiple,
      type: FileType.custom,
      allowedExtensions: _extensionsFor(slot.type),
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return;

    // 8MB each, checked before sending rather than after: on a phone
    // connection, discovering the limit after the upload is a wasted bundle.
    const limit = 8 * 1024 * 1024;
    final tooBig = result.files.where((f) => f.size > limit).toList();
    final ok = result.files.where((f) => f.size <= limit && f.path != null).toList();

    setState(() {
      if (slot.multiple) {
        _picked.putIfAbsent(slot.type, () => []);
        _picked[slot.type] = [..._picked[slot.type]!, ...ok].take(6).toList();
      } else {
        _picked[slot.type] = ok.take(1).toList();
      }
      _error = tooBig.isEmpty
          ? null
          : '${tooBig.first.name} is larger than 8MB and was not attached.';
    });
  }

  void _remove(String type, PlatformFile file) {
    setState(() {
      _picked[type] = (_picked[type] ?? []).where((f) => f != file).toList();
      if (_picked[type]!.isEmpty) _picked.remove(type);
    });
  }

  bool get _hasCv => (_picked['cv'] ?? const []).isNotEmpty;

  /// What the whole questionnaire is worth.
  int get _assessmentTotal =>
      widget.questions.fold(0, (sum, q) => sum + q.marks);

  bool get _answeredEverything =>
      widget.questions.every((q) => (_answers[q.id] ?? '').isNotEmpty);

  Future<void> _submit() async {
    if (!_hasCv) {
      setState(() => _error = 'Please attach your CV.');
      return;
    }

    // The server refuses a half-filled questionnaire, so say so here rather
    // than letting somebody upload a set of documents and be turned back.
    if (!_answeredEverything) {
      final answered =
          _answers.entries.where((e) => e.value.trim().isNotEmpty).length;
      final missing = widget.questions.length - answered;
      setState(() => _error = missing == 1
          ? 'One screening question still needs an answer.'
          : '$missing screening questions still need answers.');
      return;
    }

    setState(() {
      _sending = true;
      _progress = 0;
      _error = null;
    });

    try {
      final form = FormData();

      if (_coverLetter.text.trim().isNotEmpty) {
        form.fields.add(MapEntry('cover_letter', _coverLetter.text.trim()));
      }

      for (final entry in _answers.entries) {
        form.fields.add(MapEntry('screening[${entry.key}]', entry.value));
      }

      for (final slot in widget.slots) {
        final files = _picked[slot.type] ?? const [];
        for (final f in files) {
          final part = await MultipartFile.fromFile(f.path!, filename: f.name);
          form.files.add(MapEntry(
            slot.type == 'cv'
                ? 'cv'
                : slot.multiple
                    ? 'documents[${slot.type}][]'
                    : 'documents[${slot.type}]',
            part,
          ));
        }
      }

      final data = await CareersApi.applyWithProgress(
        widget.job.id,
        form,
        (sent, total) {
          if (total > 0 && mounted) setState(() => _progress = sent / total);
        },
      );

      await ref.read(careersProvider.notifier).afterApply();

      if (!mounted) return;
      final application =
          JobApplication.fromJson(Map<String, dynamic>.from(data['application'] as Map));
      Navigator.of(context).pop(true);
      _showReceipt(application);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showReceipt(JobApplication application) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Application sent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Keep this reference. You can use it to check your application at any time.'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                application.trackingCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 3),
              ),
            ),
            if (application.assessment != null) ...[
              const SizedBox(height: 14),
              Text(
                'Your initial assessment score: ${application.assessment!.percentage.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'This is one part of how applications are reviewed. Your documents and written answers are read by a person.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Apply',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(widget.job.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 19, color: AppColors.error),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
                          ),
                        ],
                      ),
                    ),

                  const _Label('Your documents'),
                  const Text('Attach what you have. You can be asked for the rest later.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 11),
                  ...widget.slots.map(_slotTile),

                  const SizedBox(height: 18),
                  const _Label('Cover letter'),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _coverLetter,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: 'Optional. A few lines about why you are a good fit.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                  ),

                  if (widget.questions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const _Label('Screening questions'),
                        const Spacer(),
                        if (_assessmentTotal > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('$_assessmentTotal marks',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                          ),
                      ],
                    ),
                    const Text(
                        'Every question must be answered. You will see your score as soon as you submit.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 11),
                    ...widget.questions.map(_questionTile),
                  ],

                  const SizedBox(height: 22),
                  if (_sending) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress == 0 ? null : _progress,
                        minHeight: 7,
                        backgroundColor: AppColors.divider,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _progress >= 1
                            ? 'Finishing up...'
                            : 'Uploading ${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: (_hasCv && _answeredEverything) ? _submit : null,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                      icon: const Icon(Icons.send),
                      label: Text(
                        widget.questions.isNotEmpty && !_answeredEverything
                            ? 'Answer every question to submit'
                            : 'Submit application',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Your documents are stored privately and seen only by the recruitment team.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotTile(DocumentSlot slot) {
    final files = _picked[slot.type] ?? const <PlatformFile>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: files.isEmpty ? AppColors.surface : AppColors.infoLight,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: slot.required && files.isEmpty ? AppColors.error : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(slot.label,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (slot.required)
                      const Text(' *', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _sending ? null : () => _pick(slot),
                icon: const Icon(Icons.attach_file, size: 16),
                label: Text(files.isEmpty ? 'Attach' : 'Add', style: const TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ],
          ),
          if (slot.multiple && files.isEmpty)
            const Text('You may attach several', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ...files.map((f) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    ),
                    Text(_size(f.size),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _sending ? null : () => _remove(slot.type, f),
                      icon: const Icon(Icons.close, size: 15),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _questionTile(ScreeningQuestion q) {
    Widget input;

    switch (q.type) {
      case 'multiple_choice':
        input = RadioGroup<String>(
          groupValue: _answers[q.id],
          onChanged: (v) => setState(() => _answers[q.id] = v ?? ''),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(q.options.length, (i) {
              final option = q.options[i];
              return RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: '$i',
                title: Row(
                  children: [
                    Expanded(
                      child: Text(option.text, style: const TextStyle(fontSize: 12.5)),
                    ),
                    // What each answer is worth, so the applicant is not
                    // guessing which one the employer is after.
                    if (option.marks > 0)
                      Text('${_trimMarks(option.marks)} mk',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted)),
                  ],
                ),
              );
            }),
          ),
        );
        break;

      case 'yes_no':
        input = Row(
          children: ['yes', 'no'].map((v) {
            final selected = _answers[q.id] == v;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(v == 'yes' ? 'Yes' : 'No'),
                selected: selected,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary),
                onSelected: (_) => setState(() => _answers[q.id] = v),
              ),
            );
          }).toList(),
        );
        break;

      case 'scale':
        input = Row(
          children: List.generate(5, (i) {
            final v = '${i + 1}';
            final selected = _answers[q.id] == v;
            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                label: Text(v),
                selected: selected,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary),
                onSelected: (_) => setState(() => _answers[q.id] = v),
              ),
            );
          }),
        );
        break;

      default:
        input = TextField(
          maxLines: 3,
          onChanged: (v) => _answers[q.id] = v,
          decoration: InputDecoration(
            hintText: 'Your answer',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(q.question,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: q.isScored ? AppColors.infoLight : AppColors.divider,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  q.isScored ? '${q.marks} ${q.marks == 1 ? "mark" : "marks"}' : 'Not marked',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: q.isScored ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          input,
        ],
      ),
    );
  }

  static String _trimMarks(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).round()} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary),
      );
}
