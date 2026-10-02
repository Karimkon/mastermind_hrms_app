import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/careers_model.dart';
import '../../core/providers/careers_provider.dart';
import '../../core/services/careers_api.dart';
import 'apply_form.dart';

/// One vacancy, and the way to apply for it.
///
/// Anybody can read the posting. Applying needs an account, and the screen
/// says so rather than hiding the Apply button: somebody should be able to
/// read the whole job before deciding to sign up for anything.
class CareersJobScreen extends ConsumerStatefulWidget {
  final int jobId;
  const CareersJobScreen({super.key, required this.jobId});

  @override
  ConsumerState<CareersJobScreen> createState() => _CareersJobScreenState();
}

class _CareersJobScreenState extends ConsumerState<CareersJobScreen> {
  bool _loading = true;
  String? _error;

  CareerJob? _job;
  List<DocumentSlot> _slots = const [];
  List<ScreeningQuestion> _questions = const [];

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
      final data = await CareersApi.job(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = CareerJob.fromJson(Map<String, dynamic>.from(data['job'] as Map));
        _slots = ((data['documents'] as List?) ?? const [])
            .whereType<Map>()
            .map((d) => DocumentSlot.fromJson(Map<String, dynamic>.from(d)))
            .toList();
        final screening = data['screening'] as Map?;
        _questions = screening == null
            ? const []
            : ((screening['questions'] as List?) ?? const [])
                .whereType<Map>()
                .map((q) => ScreeningQuestion.fromJson(Map<String, dynamic>.from(q)))
                .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(careersProvider).signedIn;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_job?.title ?? 'Position', maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBody()
              : _body(signedIn),
    );
  }

  Widget _errorBody() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 42, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );

  Widget _body(bool signedIn) {
    final job = _job!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.title,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.25)),
              if (job.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(job.subtitle!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  if (job.typeLabel.isNotEmpty) _pill(job.typeLabel),
                  _pill('${job.vacancies} ${job.vacancies == 1 ? "vacancy" : "vacancies"}'),
                  _pill('${job.applicants} ${job.applicants == 1 ? "applicant" : "applicants"} so far'),
                  if (job.deadline != null) _pill('Closes ${job.deadline}'),
                ],
              ),
            ],
          ),
        ),
        if ((job.description ?? '').isNotEmpty) _section('About the role', job.description!),
        if ((job.requirements ?? '').isNotEmpty) _section('What we are looking for', job.requirements!),
        if ((job.benefits ?? '').isNotEmpty) _section('What we offer', job.benefits!),
        const SizedBox(height: 4),
        if (job.alreadyApplied)
          _card(
            background: AppColors.successLight,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF065F46)),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text('You have already applied for this position.',
                      style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => context.push('/careers/applications'),
                  child: const Text('View'),
                ),
              ],
            ),
          )
        else if (!signedIn)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('To apply, you need an account',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 5),
                const Text(
                  'It takes a minute, and it lets you follow your application and hear about new jobs in your line of work.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => context.push('/careers/register'),
                        child: const Text('Create account'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push('/careers/sign-in'),
                        child: const Text('Sign in'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          FilledButton.icon(
            onPressed: () => _openApplyForm(job),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            icon: const Icon(Icons.send),
            label: const Text('Apply for this position',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  void _openApplyForm(CareerJob job) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ApplyForm(job: job, slots: _slots, questions: _questions),
    ).then((applied) {
      if (applied == true && mounted) _load();
    });
  }

  Widget _card({required Widget child, Color? background}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: background ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );

  Widget _section(String title, String body) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 7),
            Text(body,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
          ],
        ),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
}
