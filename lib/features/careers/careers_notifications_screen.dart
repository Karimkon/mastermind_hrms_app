import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/careers_model.dart';
import '../../core/providers/careers_provider.dart';

/// What the applicant has been told, in the app.
///
/// The same notices also go out by email and, once a gateway is configured,
/// by SMS. This is the copy that does not depend on either arriving.
class CareersNotificationsScreen extends ConsumerStatefulWidget {
  const CareersNotificationsScreen({super.key});

  @override
  ConsumerState<CareersNotificationsScreen> createState() =>
      _CareersNotificationsScreenState();
}

class _CareersNotificationsScreenState extends ConsumerState<CareersNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(careersProvider.notifier);
      await notifier.loadNotices();
      // Opening the screen is reading them.
      await notifier.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careersProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: !state.signedIn
          ? Center(
              child: FilledButton(
                onPressed: () => context.push('/careers/sign-in'),
                child: const Text('Sign in'),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(careersProvider.notifier).loadNotices(),
              child: state.notices.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(32, 70, 32, 32),
                      children: const [
                        Icon(Icons.notifications_none, size: 46, color: AppColors.textMuted),
                        SizedBox(height: 14),
                        Center(
                          child: Text('Nothing yet',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        SizedBox(height: 6),
                        Center(
                          child: Text(
                            'When your application moves, or a job opens in one of your categories, it will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                      itemCount: state.notices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (_, i) => _NoticeTile(notice: state.notices[i]),
                    ),
            ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  final SeekerNotice notice;
  const _NoticeTile({required this.notice});

  bool get _isJob => notice.type == 'new_job';

  void _open(BuildContext context) {
    if (_isJob) {
      final jobId = notice.data['job_id'];
      if (jobId is int) context.push('/careers/jobs/$jobId');
      return;
    }

    final id = notice.data['candidate_id'];
    if (id is int) {
      context.push('/careers/applications/$id');
      return;
    }

    final code = notice.data['tracking_code'];
    if (code is String && code.isNotEmpty) context.push('/careers/track/$code');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notice.read ? Colors.white : AppColors.infoLight,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: notice.read ? AppColors.cardBorder : const Color(0xFFBFDBFE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _isJob ? AppColors.warningLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isJob ? Icons.work_outline : Icons.timeline,
                size: 18,
                color: _isJob ? const Color(0xFF92400E) : const Color(0xFF065F46),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  if ((notice.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(notice.body!,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary, height: 1.45)),
                  ],
                  if (notice.createdAt != null) ...[
                    const SizedBox(height: 5),
                    Text(_when(notice.createdAt!),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _when(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"} ago';
    if (diff.inDays < 7) return '${diff.inDays} ${diff.inDays == 1 ? "day" : "days"} ago';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
