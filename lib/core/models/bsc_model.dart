class BscCycleModel {
  final int id;
  final String name;
  final int year;
  final String period;
  final String status;
  final String? startDate;
  final String? endDate;
  final int? krasCount;

  const BscCycleModel({
    required this.id,
    required this.name,
    required this.year,
    required this.period,
    required this.status,
    this.startDate,
    this.endDate,
    this.krasCount,
  });

  factory BscCycleModel.fromJson(Map<String, dynamic> j) => BscCycleModel(
        id:        j['id'],
        name:      j['name'] ?? '',
        year:      j['year'] ?? 0,
        period:    j['period'] ?? '',
        status:    j['status'] ?? 'draft',
        startDate: j['start_date'],
        endDate:   j['end_date'],
        krasCount: j['kras_count'] as int?,
      );

  bool get isActive  => status == 'active';
  bool get isDraft   => status == 'draft';
  bool get isClosed  => status == 'closed';
}

class BscKraModel {
  final int id;
  final int cycleId;
  final String perspective;
  final String kraName;
  final String? objective;
  final String? measure;
  final double target;
  final String? unit;
  final double weightage;
  final String reviewFrequency;

  const BscKraModel({
    required this.id,
    required this.cycleId,
    required this.perspective,
    required this.kraName,
    this.objective,
    this.measure,
    required this.target,
    this.unit,
    required this.weightage,
    required this.reviewFrequency,
  });

  factory BscKraModel.fromJson(Map<String, dynamic> j) => BscKraModel(
        id:              j['id'],
        cycleId:         j['cycle_id'],
        perspective:     j['perspective'] ?? '',
        kraName:         j['kra_name'] ?? '',
        objective:       j['objective'],
        measure:         j['measure'],
        target:          (j['target'] as num?)?.toDouble() ?? 0,
        unit:            j['unit'],
        weightage:       (j['weightage'] as num?)?.toDouble() ?? 0,
        reviewFrequency: j['review_frequency'] ?? 'annual',
      );

  String get perspectiveLabel => const {
    'financial':        'Financial',
    'customer':         'Customer',
    'internal_process': 'Internal Process',
    'learning_growth':  'Learning & Growth',
  }[perspective] ?? perspective;
}

class BscEntryModel {
  final int id;
  final int kraId;
  final int employeeId;
  final double? actualAchieved;
  final double? targetPercent;
  final int? rating;
  final double? weightedIndex;
  final String? employeeComment;
  final String? appraiserComment;
  final String? problemAreas;
  final String? remedialActions;
  final String? remedialByWhen;
  final String status;
  final String? submittedAt;
  final String? approvedAt;

  const BscEntryModel({
    required this.id,
    required this.kraId,
    required this.employeeId,
    this.actualAchieved,
    this.targetPercent,
    this.rating,
    this.weightedIndex,
    this.employeeComment,
    this.appraiserComment,
    this.problemAreas,
    this.remedialActions,
    this.remedialByWhen,
    required this.status,
    this.submittedAt,
    this.approvedAt,
  });

  factory BscEntryModel.fromJson(Map<String, dynamic> j) => BscEntryModel(
        id:               j['id'],
        kraId:            j['kra_id'],
        employeeId:       j['employee_id'],
        actualAchieved:   (j['actual_achieved'] as num?)?.toDouble(),
        targetPercent:    (j['target_percent'] as num?)?.toDouble(),
        rating:           j['rating'] as int?,
        weightedIndex:    (j['weighted_index'] as num?)?.toDouble(),
        employeeComment:  j['employee_comment'],
        appraiserComment: j['appraiser_comment'],
        problemAreas:     j['problem_areas'],
        remedialActions:  j['remedial_actions'],
        remedialByWhen:   j['remedial_by_when'],
        status:           j['status'] ?? 'draft',
        submittedAt:      j['submitted_at'],
        approvedAt:       j['approved_at'],
      );

  bool get isDraft     => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isApproved  => status == 'approved';
}

class BscKraWithEntry {
  final BscKraModel kra;
  final BscEntryModel? entry;

  const BscKraWithEntry({required this.kra, this.entry});

  factory BscKraWithEntry.fromJson(Map<String, dynamic> j) => BscKraWithEntry(
        kra:   BscKraModel.fromJson(j['kra']),
        entry: j['entry'] != null ? BscEntryModel.fromJson(j['entry']) : null,
      );
}

class BscTeamMember {
  final int employeeId;
  final String fullName;
  final String? empNumber;
  final String? department;
  final String? designation;
  final int entryCount;
  final int totalKras;
  final double overallScore;
  final int progress;
  final int approvedCount;
  final int submittedCount;

  const BscTeamMember({
    required this.employeeId,
    required this.fullName,
    this.empNumber,
    this.department,
    this.designation,
    required this.entryCount,
    required this.totalKras,
    required this.overallScore,
    required this.progress,
    required this.approvedCount,
    required this.submittedCount,
  });

  factory BscTeamMember.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] as Map<String, dynamic>;
    return BscTeamMember(
      employeeId:    emp['id'],
      fullName:      emp['full_name'] ?? '',
      empNumber:     emp['emp_number'],
      department:    emp['department'],
      designation:   emp['designation'],
      entryCount:    j['entry_count'] ?? 0,
      totalKras:     j['total_kras'] ?? 0,
      overallScore:  (j['overall_score'] as num?)?.toDouble() ?? 0,
      progress:      j['progress'] ?? 0,
      approvedCount: j['approved_count'] ?? 0,
      submittedCount:j['submitted_count'] ?? 0,
    );
  }
}
