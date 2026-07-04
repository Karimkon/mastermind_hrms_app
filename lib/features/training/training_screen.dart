import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/training_provider.dart';

class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(trainingCoursesProvider);
    final certsAsync = ref.watch(certificationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Certifications row
          certsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (certs) => certs.isEmpty ? const SizedBox.shrink() : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MY CERTIFICATIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
                const SizedBox(height: 12),
                Row(children: certs.take(4).map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: _CertCard(cert: c)))).toList()),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Courses
          const Text('AVAILABLE COURSES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          coursesAsync.when(
            loading: () => Shimmer.fromColors(
              baseColor: const Color(0xFFE2E8F0),
              highlightColor: const Color(0xFFF8FAFC),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 16, mainAxisSpacing: 16),
                itemCount: 6,
                itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
              ),
            ),
            error: (e, _) => Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textMuted),
                const SizedBox(height: 8),
                Text(e.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              ]),
            )),
            data: (courses) {
              if (courses.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.school_rounded, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('No courses available', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.3,
                ),
                itemCount: courses.length,
                itemBuilder: (_, i) => _CourseCard(course: courses[i], ref: ref),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CertCard extends StatelessWidget {
  final Map<String, dynamic> cert;
  const _CertCard({required this.cert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.success, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cert['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                Text(cert['expires_at'] != null ? 'Expires: ${cert['expires_at']}' : 'No expiry',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final WidgetRef ref;
  const _CourseCard({required this.course, required this.ref});

  @override
  Widget build(BuildContext context) {
    final enrolled = course['is_enrolled'] as bool? ?? false;
    final progress = (course['progress'] as num?)?.toInt() ?? 0;

    const colors = [
      [AppColors.primary, AppColors.primaryDark],
      [AppColors.success, Color(0xFF059669)],
      [AppColors.warning, Color(0xFFD97706)],
      [AppColors.chart5, Color(0xFF7C3AED)],
      [AppColors.error, Color(0xFFDC2626)],
    ];
    final colorPair = colors[(course['id'] as int? ?? 0) % colors.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colorPair, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Center(child: Icon(Icons.school_rounded, color: Colors.white.withValues(alpha: 0.9), size: 36)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  if (enrolled && progress > 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: progress / 100, minHeight: 4, backgroundColor: AppColors.surface, color: colorPair[0]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$progress%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: enrolled
                        ? OutlinedButton(
                            onPressed: () => _showProgressDialog(context, ref, course, colorPair[0]),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8), side: BorderSide(color: colorPair[0])),
                            child: Text('Continue', style: TextStyle(color: colorPair[0], fontSize: 12, fontWeight: FontWeight.w700)),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              final ok = await ref.read(trainingActionsProvider.notifier).enroll(course['id'] as int? ?? 0);
                              if (ok) {
                                ref.invalidate(trainingCoursesProvider);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorPair[0],
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Enroll', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProgressDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> course, Color color) {
    int progress = (course['progress'] as num?)?.toInt() ?? 0;
    final courseId = course['id'] as int? ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(course['title'] as String? ?? 'Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update your progress:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: progress.toDouble(),
                      min: 0, max: 100, divisions: 20,
                      activeColor: color,
                      onChanged: (v) => setState(() => progress = v.toInt()),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('$progress%', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (progress == 100)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      SizedBox(width: 8),
                      Text('Course completed!', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ref.read(trainingActionsProvider.notifier).updateProgress(courseId, progress);
                if (ok) {
                  ref.invalidate(trainingCoursesProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Progress updated to $progress%'),
                      backgroundColor: AppColors.success,
                    ));
                  }
                }
              },
              child: const Text('Save Progress'),
            ),
          ],
        ),
      ),
    );
  }
}
