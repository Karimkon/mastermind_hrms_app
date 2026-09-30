/// A goal set for an employee, and how far along it is.
class GoalModel {
  final int id;
  final String title;
  final String? description;
  final String? targetDate;
  final double weight;
  final int progress;
  final String status;
  final String? cycle;
  final bool setByMe;
  final int attachments;

  const GoalModel({
    required this.id,
    required this.title,
    this.description,
    this.targetDate,
    this.weight = 0,
    this.progress = 0,
    this.status = 'not_started',
    this.cycle,
    this.setByMe = false,
    this.attachments = 0,
  });

  /// The four values the column accepts. The API used to write 'active', which
  /// is not one of them, so every goal created from the phone was refused.
  static const statuses = ['not_started', 'in_progress', 'achieved', 'missed'];

  String get statusLabel => switch (status) {
        'in_progress' => 'In progress',
        'achieved' => 'Achieved',
        'missed' => 'Missed',
        _ => 'Not started',
      };

  bool get isDone => status == 'achieved' || status == 'missed';

  /// Past its date and not finished — the only state worth a warning colour.
  bool get isOverdue {
    if (isDone || targetDate == null) return false;
    final d = DateTime.tryParse(targetDate!);
    return d != null && d.isBefore(DateTime.now());
  }

  factory GoalModel.fromJson(Map<String, dynamic> j) => GoalModel(
        id: j['id'] as int,
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        targetDate: j['target_date'] as String?,
        weight: (j['weight'] as num?)?.toDouble() ?? 0,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'not_started',
        cycle: j['cycle'] as String?,
        setByMe: j['set_by_me'] as bool? ?? false,
        attachments: (j['attachments'] as num?)?.toInt() ?? 0,
      );
}

class GoalSummary {
  final int total;
  final int inProgress;
  final int achieved;
  final int progress;

  const GoalSummary({
    this.total = 0,
    this.inProgress = 0,
    this.achieved = 0,
    this.progress = 0,
  });

  factory GoalSummary.fromJson(Map<String, dynamic>? j) => GoalSummary(
        total: (j?['total'] as num?)?.toInt() ?? 0,
        inProgress: (j?['in_progress'] as num?)?.toInt() ?? 0,
        achieved: (j?['achieved'] as num?)?.toInt() ?? 0,
        progress: (j?['progress'] as num?)?.toInt() ?? 0,
      );
}

class GoalsData {
  final List<GoalModel> goals;
  final GoalSummary summary;
  const GoalsData({this.goals = const [], this.summary = const GoalSummary()});
}
