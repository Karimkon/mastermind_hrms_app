import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/models/change_approval_model.dart';
import 'package:mastermind_hrms_app/core/models/goal_model.dart';

/// The shapes the two new screens are fed, straight from the API.
void main() {
  group('GoalModel', () {
    GoalModel parse(Map<String, dynamic> extra) => GoalModel.fromJson({
          'id': 1,
          'title': 'Cut loading damage',
          'status': 'not_started',
          'progress': 0,
          ...extra,
        });

    test('reads what the endpoint sends', () {
      final g = parse({
        'description': 'Fewer breakages on the night shift',
        'target_date': '2026-12-31',
        'weight': 20,
        'progress': 45,
        'status': 'in_progress',
        'cycle': 'FY2026 Performance Cycle',
        'set_by_me': true,
        'attachments': 2,
      });

      expect(g.title, 'Cut loading damage');
      expect(g.weight, 20);
      expect(g.progress, 45);
      expect(g.statusLabel, 'In progress');
      expect(g.cycle, 'FY2026 Performance Cycle');
      expect(g.attachments, 2);
      expect(g.isDone, isFalse);
    });

    test('only the four statuses the column accepts are known', () {
      // 'active' was what the API used to write, and the database refused it.
      expect(GoalModel.statuses, ['not_started', 'in_progress', 'achieved', 'missed']);
      expect(GoalModel.statuses, isNot(contains('active')));
    });

    test('a finished goal is not overdue, whatever its date', () {
      final missed = parse({'status': 'achieved', 'target_date': '2020-01-01'});
      expect(missed.isOverdue, isFalse, reason: 'it is done — the date no longer matters');
      expect(missed.isDone, isTrue);
    });

    test('an unfinished goal past its date is overdue', () {
      expect(parse({'target_date': '2020-01-01'}).isOverdue, isTrue);
      expect(parse({'target_date': '2099-01-01'}).isOverdue, isFalse);
      expect(parse({}).isOverdue, isFalse, reason: 'no date set, nothing to be late for');
    });

    test('a summary survives the key being absent altogether', () {
      final s = GoalSummary.fromJson(null);
      expect(s.total, 0);
      expect(s.progress, 0);
    });
  });

  group('ChangeApprovalModel', () {
    test('reads the queue row', () {
      final c = ChangeApprovalModel.fromJson({
        'id': 7,
        'action': 'update',
        'label': 'Ashiraf Lule',
        'model_type': 'Employee',
        'status': 'pending',
        'requested_by': 'Omar Shamillah',
        'client': 'Roofings Uganda Limited',
        'field_count': 3,
        'created_at': '2026-09-30 11:00',
      });

      expect(c.subjectLabel, 'Ashiraf Lule');
      expect(c.isPending, isTrue);
      expect(c.fieldCount, 3);
      expect(c.diff, isEmpty, reason: 'the list does not carry the diff; the detail call does');
    });

    test('the detail call carries the field-by-field diff', () {
      final c = ChangeApprovalModel.fromJson({
        'id': 7,
        'label': 'Ashiraf Lule',
        'status': 'pending',
        'has_drift': true,
        'subject_gone': false,
        'diff': [
          {'field': 'phone', 'was': null, 'proposed': '+256700000001', 'current': '+256711111111', 'drifted': true},
          {'field': 'bank_account', 'was': '123', 'proposed': '456', 'current': '123', 'drifted': false},
        ],
      });

      expect(c.diff, hasLength(2));
      expect(c.hasDrift, isTrue);
      expect(c.diff.first.drifted, isTrue,
          reason: 'somebody moved this field after the change was proposed');
      expect(c.diff.last.drifted, isFalse);
    });

    test('a field name reads as words', () {
      const row = ChangeDiffRow(field: 'mobile_money_number');
      expect(row.label, 'Mobile money number');
    });

    test('booleans and blanks are shown as something a person can read', () {
      final rows = [
        ChangeDiffRow.fromJson({'field': 'on_hold', 'proposed': true, 'current': false}),
        ChangeDiffRow.fromJson({'field': 'phone', 'proposed': '   ', 'current': null}),
      ];

      expect(rows.first.proposed, 'Yes');
      expect(rows.first.current, 'No');
      expect(rows.last.proposed, isNull, reason: 'whitespace is not a value');
      expect(rows.last.current, isNull);
    });

    test('a decided change is no longer pending', () {
      final c = ChangeApprovalModel.fromJson({
        'id': 7,
        'status': 'rejected',
        'reviewed_by': 'Ian Kirabo',
        'review_note': 'Wrong number.',
      });

      expect(c.isPending, isFalse);
      expect(c.reviewNote, 'Wrong number.');
    });
  });
}
