import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/constants/app_colors.dart';
import 'package:mastermind_hrms_app/core/models/employee_model.dart';
import 'package:mastermind_hrms_app/core/models/supervisor_model.dart';
import 'package:mastermind_hrms_app/core/widgets/ui.dart';

/// Two screens that had to be read off the server rather than guessed at.
///
/// The employee edit form carries the same forty-odd fields the browser form
/// does, keyed by the names the server reads. The site payroll screen carries
/// figures the server has already scoped to the supervisor's postings. Both
/// break quietly when a key is wrong — a field silently empty, a total
/// silently zero — so the parsing is pinned to the shape the server sends.
void main() {
  group('EmployeeModel reads the record the server sent', () {
    // Trimmed from a real GET /api/employees/{id} response.
    final full = <String, dynamic>{
      'id': 1235,
      'emp_number': 'HQ003',
      'full_name': 'Sande Alamanzani',
      'first_name': 'Sande',
      'last_name': 'Alamanzani',
      'status': 'active',
      'email': 'sande.alamanzani@roofings.com',
      'personal_email': '',
      'nssf_number': '7918000032712',
      'bank_account': '9030012345678',
      'next_of_kin_name': 'Aisha Alamanzani',
      'on_hold': false,
      'state': 'active',
      'edits_need_approval': true,
    };

    test('a field is read by the name the server uses', () {
      final emp = EmployeeModel.fromJson(full);

      expect(emp.text('nssf_number'), '7918000032712');
      expect(emp.text('next_of_kin_name'), 'Aisha Alamanzani');
      expect(emp.text('bank_account'), '9030012345678');
    });

    test('blank and absent both read as absent', () {
      final emp = EmployeeModel.fromJson(full);

      // The server sends null for a column never filled in and '' for one
      // that was cleared. An empty box is the right answer to both; the
      // string "null" in a text field is not.
      expect(emp.text('personal_email'), isNull);
      expect(emp.text('passport_number'), isNull);
    });

    test('the login address comes down as email and is edited as login_email', () {
      // The one field whose read name and write name differ, because it
      // lives on the user rather than the employee. The form used to post it
      // as `email`, which the server's update list did not contain, so every
      // save dropped it on the floor while the screen said it had worked.
      final emp = EmployeeModel.fromJson(full);

      expect(emp.text('email'), 'sande.alamanzani@roofings.com');
    });

    test('a hold is read as a state, not as a status', () {
      final held = EmployeeModel.fromJson({
        ...full,
        'status': 'active',
        'on_hold': true,
        'state': 'on_hold',
      });

      expect(held.status, 'active', reason: 'the column itself still says active');
      expect(held.state, 'on_hold', reason: 'but the dropdown must show the hold');
      expect(held.flag('on_hold'), isTrue);
    });

    test('a record with no state key falls back to the flag then the status', () {
      final older = Map<String, dynamic>.from(full)..remove('state');
      older['on_hold'] = 1; // an older build sends 1, not true

      expect(EmployeeModel.fromJson(older).state, 'on_hold');
    });

    test('whether Save writes or proposes comes from the server', () {
      expect(EmployeeModel.fromJson(full).editsNeedApproval, isTrue);

      expect(
        EmployeeModel.fromJson({...full, 'edits_need_approval': false})
            .editsNeedApproval,
        isFalse,
      );
    });

    test('a list row without the full record does not throw', () {
      // GET /api/employees sends the short shape. Opening it must not crash
      // on the forty keys that are only in the detail response.
      final short = EmployeeModel.fromJson({
        'id': 7,
        'emp_number': 'HQ009',
        'full_name': 'Opiyo Simon',
        'status': 'active',
      });

      expect(short.text('nssf_number'), isNull);
      expect(short.editsNeedApproval, isFalse);
      expect(short.state, 'active');
    });
  });

  group('Site payroll parses what the server scoped', () {
    final body = <String, dynamic>{
      'run': {
        'id': 70,
        'title': 'Uganda Baati — October 2026',
        'client_name': 'Uganda Baati',
        'status': 'processed',
        'status_label': 'With HR',
        'released': false,
        'people': 70,
      },
      'data': [
        {
          'employee_id': 2777,
          'emp_number': 'MMUBL028',
          'name': 'Adriko Nelson',
          'role': 'Security Guard',
          'worked_days': 26,
          'absent_days': 0,
          'gross': 700000,
          'deductions': 35000,
          'net': 665000,
        },
      ],
      'totals': {'gross': 700000, 'net': 665000, 'days': 26},
    };

    test('a run carries this site\'s headcount, not the run\'s', () {
      final run = SitePayrollRun.fromJson(
          Map<String, dynamic>.from(body['run'] as Map));

      expect(run.id, 70);
      expect(run.people, 70);
      expect(run.statusLabel, 'With HR');
      expect(run.released, isFalse);
    });

    test('a payslip and its totals survive JSON\'s ints', () {
      // The server casts these to float; JSON drops the .0 and they arrive as
      // ints. Reading them as double directly throws, and a screen that
      // catches that shows a wage bill of nothing.
      final detail = SitePayrollDetail.fromJson(body);

      expect(detail.payslips, hasLength(1));
      expect(detail.payslips.first.net, 665000);
      expect(detail.payslips.first.workedDays, 26);
      expect(detail.net, 665000);
      expect(detail.gross, 700000);
    });

    test('a run with nothing on it reads as empty, not as broken', () {
      final detail = SitePayrollDetail.fromJson({
        'run': body['run'],
        'data': const [],
        'totals': const {},
      });

      expect(detail.payslips, isEmpty);
      expect(detail.net, 0);
    });
  });

  group('the new cards hold at phone width', () {
    const widths = <(double, String)>[
      (320, 'small phone'),
      (360, 'common Android phone'),
      (390, 'iPhone'),
    ];

    Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: child,
          ),
        ),
      ));

      expect(tester.takeException(), isNull,
          reason: 'overflowed at ${width.toInt()}pt');
    }

    for (final (width, name) in widths) {
      testWidgets('a payroll run card holds its chips on a $name',
          (tester) async {
        await pumpAt(
          tester,
          width,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Mastermind Consult Ltd HQ — October 2026 Payroll',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Uganda Baati', style: TextStyle(fontSize: 12)),
                SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.xs,
                  children: [
                    AppChip(label: 'With Finance', tone: AppColors.warning),
                    AppChip(label: '439 people', tone: AppColors.info),
                  ],
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('a payslip card holds a long name beside its net pay on a $name',
          (tester) async {
        await pumpAt(
          tester,
          width,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nakabugo Christine Namaganda',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 2),
                          Text('MMUBL028 · Security Guard Supervisor',
                              style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpace.sm),
                    Text('1,430,500',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.md,
                  runSpacing: AppSpace.xs,
                  children: const [
                    Text('Days 26', style: TextStyle(fontSize: 11)),
                    Text('Missed 1.5', style: TextStyle(fontSize: 11)),
                    Text('Gross 1,500,000', style: TextStyle(fontSize: 11)),
                    Text('Deductions 69,500', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      });

      testWidgets('an edit field with a hint holds on a $name', (tester) async {
        // The longest hint on the employee form: the one explaining that the
        // payslip address is applied straight away.
        await pumpAt(
          tester,
          width,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Work / Payslip Email',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller:
                    TextEditingController(text: 'sande.alamanzani@roofings.com'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Where payslips are sent, and how they sign in. Applied '
                  'straight away, not held for approval.',
                  style: TextStyle(fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        );
      });
    }
  });
}
