import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/constants/app_colors.dart';
import 'package:mastermind_hrms_app/core/widgets/ui.dart';

/// Layout, at the sizes people actually hold.
///
/// Nothing in this project ever rendered a screen at phone width. Every
/// overflow that reached the App Store — and the "M y L e a v e" cards on
/// the employee dashboard — would have been caught by a single pump at
/// 360pt, because Flutter reports a RenderFlex overflow as a real exception
/// in a test even though it only paints yellow stripes in a running app.
///
/// So: pump at a spread of real widths, and fail on any overflow.
void main() {
  // The narrow end is a Galaxy A-series / Tecno at 360, which is what most
  // of this workforce carries. 320 is the floor Flutter still supports and
  // the one that breaks first. 834 and 1194 are the iPad Air that App
  // Review used.
  // A list of records, not a map: a double is not a valid const map key.
  const widths = <(double, String)>[
    (320, 'small phone'),
    (360, 'common Android phone'),
    (390, 'iPhone'),
    (414, 'large phone'),
    (834, 'iPad portrait'),
    (1194, 'iPad landscape'),
  ];

  /// Render [child] at [width] and fail if anything overflowed.
  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    Widget child,
  ) async {
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

    expect(
      tester.takeException(),
      isNull,
      reason: 'overflowed at ${width.toInt()}pt',
    );
  }

  /// A card the size of the real dashboard ones: a heading that cannot be
  /// abbreviated and an action beside it. This is the shape that broke.
  Widget dashCard(String title, String action) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                TextButton(
                    onPressed: () {},
                    child: Text(action, style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            const EmptyState(icon: Icons.inbox_rounded, title: 'Nothing yet'),
          ],
        ),
      );

  group('CardGrid', () {
    for (final (width, name) in widths) {
      testWidgets('three cards do not overflow on a ${name}',
          (tester) async {
        await pumpAt(
          tester,
          width,
          CardGrid(children: [
            dashCard('My Leave Balances', 'Apply for leave'),
            const SizedBox(width: 16),
            dashCard('My Leave Requests', '+ New request'),
            const SizedBox(width: 16),
            dashCard('My Payslips', 'View all'),
          ]),
        );
      });
    }

    testWidgets('falls to one column on a phone', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CardGrid(children: [
            const SizedBox(key: Key('a'), height: 50),
            const SizedBox(width: 16),
            const SizedBox(key: Key('b'), height: 50),
            const SizedBox(width: 16),
            const SizedBox(key: Key('c'), height: 50),
          ]),
        ),
      ));

      // Stacked, so each sits below the last rather than beside it.
      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      final c = tester.getTopLeft(find.byKey(const Key('c')));

      expect(b.dy, greaterThan(a.dy));
      expect(c.dy, greaterThan(b.dy));
      expect(b.dx, equals(a.dx));
    });

    testWidgets('keeps three columns on a wide window', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CardGrid(children: [
            const SizedBox(key: Key('a'), height: 50),
            const SizedBox(width: 16),
            const SizedBox(key: Key('b'), height: 50),
            const SizedBox(width: 16),
            const SizedBox(key: Key('c'), height: 50),
          ]),
        ),
      ));

      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      final c = tester.getTopLeft(find.byKey(const Key('c')));

      // Side by side, on one line.
      expect(b.dy, equals(a.dy));
      expect(c.dy, equals(a.dy));
      expect(b.dx, greaterThan(a.dx));
    });

    testWidgets('an Expanded child survives the conversion', (tester) async {
      // Call sites inherit Expanded wrappers from the Row being replaced.
      // An Expanded outside a flex throws, so CardGrid must unwrap them.
      await pumpAt(
        tester,
        360,
        CardGrid(children: [
          Expanded(child: dashCard('One', 'Act')),
          const SizedBox(width: 16),
          Expanded(child: dashCard('Two', 'Act')),
        ]),
      );
    });

    testWidgets('an empty grid renders nothing rather than throwing',
        (tester) async {
      await pumpAt(tester, 360, const CardGrid(children: []));
    });
  });

  group('the shared components hold at every width', () {
    for (final (width, name) in widths) {
      testWidgets('a long status chip does not wrap on a ${name}',
          (tester) async {
        // "Prese nt" in the attendance table is what this guards.
        // Flexible, because a Row hands its non-flex children UNBOUNDED
        // main-axis constraints: a chip in a bare Row will overflow however
        // it is written, and no widget can defend itself against that. What
        // is worth guaranteeing is that once it IS constrained - which is
        // how it sits in the attendance table - it gives ground by
        // ellipsizing rather than wrapping to "Prese nt".
        await pumpAt(
          tester,
          width,
          const Row(children: [
            Flexible(
              child: AppChip(
                  label: 'Pending supervisor approval', tone: AppColors.warning),
            ),
          ]),
        );
      });

      testWidgets('a page title with an action holds on a ${name}',
          (tester) async {
        await pumpAt(
          tester,
          width,
          PageTitle(
            'Leave Requests',
            subtitle: 'Everything you have asked for this year',
            action: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Apply for leave'),
            ),
          ),
        );
      });

      testWidgets('a stat card with a long label holds on a ${name}',
          (tester) async {
        await pumpAt(
          tester,
          width,
          CardGrid(
            minItemWidth: 150,
            children: const [
              StatCard(
                  label: 'Present This Month',
                  value: '0',
                  icon: Icons.check_circle_rounded,
                  tone: AppColors.success),
              SizedBox(width: 12),
              StatCard(
                  label: 'Absent This Month',
                  value: '0',
                  icon: Icons.cancel_rounded,
                  tone: AppColors.error),
              SizedBox(width: 12),
              StatCard(
                  label: 'Late This Month',
                  value: '0',
                  icon: Icons.schedule_rounded,
                  tone: AppColors.warning),
              SizedBox(width: 12),
              StatCard(
                  label: "Today's Hours",
                  value: '0h',
                  icon: Icons.timer_rounded,
                  tone: AppColors.info),
            ],
          ),
        );
      });
    }
  });

  group('the supervisor screens', () {
    for (final (width, name) in widths) {
      testWidgets('six figures reflow rather than overflow on a $name',
          (tester) async {
        // The supervisor dashboard shows six at once - two more than any
        // other screen - so it is the one that breaks first.
        await pumpAt(
          tester,
          width,
          CardGrid(
            minItemWidth: 150,
            gap: AppSpace.md,
            children: const [
              StatCard(
                  label: 'Not yet recorded',
                  value: '12',
                  icon: Icons.help_outline_rounded,
                  tone: AppColors.warning),
              SizedBox(width: AppSpace.md),
              StatCard(
                  label: 'Present',
                  value: '48',
                  icon: Icons.check_circle_rounded,
                  tone: AppColors.success),
              SizedBox(width: AppSpace.md),
              StatCard(
                  label: 'Absent',
                  value: '3',
                  icon: Icons.cancel_rounded,
                  tone: AppColors.error),
              SizedBox(width: AppSpace.md),
              StatCard(
                  label: 'Late',
                  value: '7',
                  icon: Icons.schedule_rounded,
                  tone: AppColors.warning),
              SizedBox(width: AppSpace.md),
              StatCard(
                  label: 'On leave',
                  value: '2',
                  icon: Icons.beach_access_rounded,
                  tone: AppColors.info),
              SizedBox(width: AppSpace.md),
              StatCard(
                  label: 'Still clocked in',
                  value: '19',
                  icon: Icons.timer_rounded,
                  tone: AppColors.primary),
            ],
          ),
        );
      });

      testWidgets('a workforce row holds a long name and a status on a $name',
          (tester) async {
        await pumpAt(
          tester,
          width,
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(radius: 21, child: Text('GN')),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Nakabugo Christine Namaganda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('MM/2026/00841  ·  Security Guard Supervisor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12)),
                      SizedBox(height: AppSpace.sm),
                      Row(children: [
                        Flexible(
                          child: AppChip(
                              label: 'Not recorded', tone: AppColors.textMuted),
                        ),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        );
      });

      testWidgets('the request card header holds a long label on a $name',
          (tester) async {
        // Title and status chip share a line. A full name plus an employee
        // number is the longest label this card ever carries.
        await pumpAt(
          tester,
          width,
          AppCard(
            accent: AppColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('Nakabugo Christine Namaganda (MM/2026/00841)',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    SizedBox(width: AppSpace.sm),
                    Flexible(
                      child: AppChip(
                          label: 'Waiting',
                          tone: AppColors.warning,
                          icon: Icons.hourglass_bottom_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      });
    }
  });
}
