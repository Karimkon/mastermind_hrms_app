/// One field of a proposed change: what it was, what it would become, and
/// whether somebody else has moved it since the request was made.
class ChangeDiffRow {
  final String field;
  final String? was;
  final String? proposed;
  final String? current;
  final bool drifted;

  const ChangeDiffRow({
    required this.field,
    this.was,
    this.proposed,
    this.current,
    this.drifted = false,
  });

  /// `phone_number` reads better as `Phone number` on a small screen.
  String get label {
    final words = field.split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return field;
    final first = words.first;
    return ([first[0].toUpperCase() + first.substring(1)] + words.skip(1).toList()).join(' ');
  }

  static String? _text(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v ? 'Yes' : 'No';
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory ChangeDiffRow.fromJson(Map<String, dynamic> j) => ChangeDiffRow(
        field: j['field'] as String? ?? '',
        was: _text(j['was']),
        proposed: _text(j['proposed']),
        current: _text(j['current']),
        drifted: j['drifted'] as bool? ?? false,
      );
}

/// A change an account manager has proposed against a live record.
///
/// Nothing here has happened yet — approving is what applies it.
class ChangeApprovalModel {
  final int id;
  final String action;
  final String? label;
  final String modelType;
  final String status;
  final String? requestedBy;
  final String? client;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? reviewNote;
  final int fieldCount;
  final String? createdAt;

  final List<ChangeDiffRow> diff;
  final bool hasDrift;
  final bool subjectGone;

  const ChangeApprovalModel({
    required this.id,
    this.action = 'update',
    this.label,
    this.modelType = '',
    this.status = 'pending',
    this.requestedBy,
    this.client,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    this.fieldCount = 0,
    this.createdAt,
    this.diff = const [],
    this.hasDrift = false,
    this.subjectGone = false,
  });

  bool get isPending => status == 'pending';

  String get subjectLabel => label ?? '$modelType #$id';

  factory ChangeApprovalModel.fromJson(Map<String, dynamic> j) => ChangeApprovalModel(
        id: j['id'] as int,
        action: j['action'] as String? ?? 'update',
        label: j['label'] as String?,
        modelType: j['model_type'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        requestedBy: j['requested_by'] as String?,
        client: j['client'] as String?,
        reviewedBy: j['reviewed_by'] as String?,
        reviewedAt: j['reviewed_at'] as String?,
        reviewNote: j['review_note'] as String?,
        fieldCount: (j['field_count'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at'] as String?,
        diff: (j['diff'] as List?)
                ?.map((d) => ChangeDiffRow.fromJson(Map<String, dynamic>.from(d)))
                .toList() ??
            const [],
        hasDrift: j['has_drift'] as bool? ?? false,
        subjectGone: j['subject_gone'] as bool? ?? false,
      );
}

class ChangeApprovalsData {
  final List<ChangeApprovalModel> changes;
  final int pendingCount;
  final String status;

  const ChangeApprovalsData({
    this.changes = const [],
    this.pendingCount = 0,
    this.status = 'pending',
  });
}
