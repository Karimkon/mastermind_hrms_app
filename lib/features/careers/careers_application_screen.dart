import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/careers_model.dart';
import '../../core/services/careers_api.dart';
import 'application_progress.dart';

/// One application in full.
///
/// Two ways in, one screen: an account holder opens it by id, and anybody at
/// all opens it by the reference they were given. The reference route shows
/// exactly the same thing, because there is nothing here an applicant should
/// not see about themselves.
class CareersApplicationScreen extends ConsumerStatefulWidget {
  final int? applicationId;
  final String? trackingCode;

  const CareersApplicationScreen({super.key, this.applicationId, this.trackingCode});

  @override
  ConsumerState<CareersApplicationScreen> createState() => _CareersApplicationScreenState();
}

class _CareersApplicationScreenState extends ConsumerState<CareersApplicationScreen> {
  bool _loading = true;
  String? _error;
  JobApplication? _application;

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
      final data = widget.applicationId != null
          ? await CareersApi.application(widget.applicationId!)
          : await CareersApi.track(widget.trackingCode ?? '');

      if (!mounted) return;
      setState(() {
        _application =
            JobApplication.fromJson(Map<String, dynamic>.from(data['application'] as Map));
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Your application'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBody()
              : _body(_application!),
    );
  }

  Widget _errorBody() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 44, color: AppColors.textMuted),
              const SizedBox(height: 14),
              Text(
                widget.trackingCode != null
                    ? 'No application found with that reference. Check the characters and try again.'
                    : _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );

  Widget _body(JobApplication a) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.jobTitle,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, height: 1.25)),
                if ((a.jobLocation ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.jobLocation!,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: [
                      const Text('YOUR REFERENCE',
                          style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      Text(a.trackingCode,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (a.assessment != null) ...[
            AssessmentCard(assessment: a.assessment!),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Where your application stands',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 16),
                ApplicationProgress(stages: a.progress),
              ],
            ),
          ),
          if (a.documents.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What you attached',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: a.documents
                        .map((d) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(d,
                                  style: const TextStyle(
                                      fontSize: 11.5, color: AppColors.textSecondary)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
          if (a.updates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Updates',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  ...a.updates.map((u) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 34,
                              margin: const EdgeInsets.only(right: 11, top: 2),
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_when(u.at),
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(u.message,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textPrimary,
                                          height: 1.45)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _when(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, $hh:$mm';
  }
}
