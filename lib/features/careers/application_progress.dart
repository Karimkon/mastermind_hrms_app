import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/careers_model.dart';

/// The stages of an application, drawn once.
///
/// Used by the applications list, the single application view and the
/// track-by-reference screen, so all three say the same thing.
class ApplicationProgress extends StatelessWidget {
  final List<ProgressStage> stages;
  final bool compact;

  const ApplicationProgress({super.key, required this.stages, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();

    if (compact) {
      // A single row of dots for a list item, where the detail is not wanted.
      return Row(
        children: List.generate(stages.length * 2 - 1, (i) {
          if (i.isOdd) {
            final next = stages[(i + 1) ~/ 2];
            return Expanded(
              child: Container(
                height: 2,
                color: next.state == 'pending' ? AppColors.divider : AppColors.success,
              ),
            );
          }
          final stage = stages[i ~/ 2];
          return _dot(stage, 16);
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(stages.length, (i) {
        final stage = stages[i];
        final last = i == stages.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                _dot(stage, 26),
                if (!last)
                  Container(
                    width: 2,
                    height: 34,
                    color: stage.state == 'done' ? AppColors.success : AppColors.divider,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 14, top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stage.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: stage.state == 'pending'
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (stage.state == 'current') ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('In progress',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stage.blurb,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: stage.state == 'pending'
                            ? AppColors.textMuted
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _dot(ProgressStage stage, double size) {
    final done = stage.state == 'done';
    final current = stage.state == 'current';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.success
            : current
                ? AppColors.primary
                : AppColors.divider,
        border: current ? Border.all(color: AppColors.infoLight, width: 3) : null,
      ),
      child: done
          ? Icon(Icons.check, size: size * 0.6, color: Colors.white)
          : current
              ? Center(
                  child: Container(
                    width: size * 0.26,
                    height: size * 0.26,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  ),
                )
              : null,
    );
  }
}

/// The screening score, shown to the person who earned it.
class AssessmentCard extends StatelessWidget {
  final Assessment assessment;
  const AssessmentCard({super.key, required this.assessment});

  Color get _colour => assessment.percentage >= 70
      ? AppColors.success
      : assessment.percentage >= 50
          ? AppColors.warning
          : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your initial assessment',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    SizedBox(height: 2),
                    Text('Scored from the screening questions you answered',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Text(
                '${_trim(assessment.percentage)}%',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _colour),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (assessment.percentage / 100).clamp(0.02, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(_colour),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_trim(assessment.score)} of ${_trim(assessment.max)} marks. This is one part of how '
            'applications are reviewed; your documents and written answers are read by a person.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
