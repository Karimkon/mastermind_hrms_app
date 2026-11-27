import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/models/user_model.dart';

/// A permission granted on the web must be worth something on the phone.
///
/// The app drawer was gated on role names — isAdmin, isManager, isPayroll —
/// exactly like the web sidebar was, so somebody granted a permission saw no
/// change on either. `permissions` has been in the sign-in response and in
/// this model all along, and nothing read it.
///
/// These pin the rule itself. The drawer is built from it in app_shell.dart,
/// and the server gates the matching routes from App\Support\Nav, which this
/// mirrors — if the two drift, a menu entry starts 403ing.
void main() {
  UserModel user({List<String> roles = const [], List<String> perms = const []}) =>
      UserModel.fromJson({
        'id': 1,
        'name': 'Lawrence Matovu',
        'email': 'matovu.lawrence@roofingsgroup.com',
        'roles': roles,
        'permissions': perms,
      });

  group('mayOpen', () {
    test('a role still opens what it always opened', () {
      final hr = user(roles: ['hr-admin']);

      expect(hr.mayOpen(roles: const ['super-admin', 'hr-admin', 'manager']), isTrue);
    });

    test('a permission opens it as well', () {
      // Lawrence's case: a client given performance rights.
      final client = user(roles: ['client'], perms: ['performance.view']);

      expect(
        client.mayOpen(
          roles: const ['super-admin', 'hr-admin', 'manager'],
          perms: const ['performance.view', 'performance.manage', 'performance.review'],
        ),
        isTrue,
      );
    });

    test('and taking it away closes it again', () {
      final client = user(roles: ['client']);

      expect(
        client.mayOpen(
          roles: const ['super-admin', 'hr-admin', 'manager'],
          perms: const ['performance.view', 'performance.manage', 'performance.review'],
        ),
        isFalse,
      );
    });

    test('a different permission is not a skeleton key', () {
      final client = user(roles: ['client'], perms: ['performance.view']);

      expect(
        client.mayOpen(roles: const ['super-admin'], perms: const ['payroll.view']),
        isFalse,
      );
    });

    test('an empty permission list never opens anything on its own', () {
      // The guard that matters for modules with no permission of their own:
      // canAny([]) is false, but a careless `||` would read as true.
      expect(user(roles: ['client']).mayOpen(roles: const ['super-admin']), isFalse);
      expect(user().mayOpen(), isFalse);
    });

    test('deny beats both, for a role with its own scoped screen', () {
      // An account manager holds employees.view for their client list. That
      // is not Employee Central, which is all 1,271 staff and their banks.
      final am = user(roles: ['account-manager'], perms: ['employees.view']);

      expect(
        am.mayOpen(
          roles: const ['super-admin', 'hr-admin', 'manager'],
          perms: const ['employees.view'],
          deny: const ['account-manager'],
        ),
        isFalse,
      );

      // But the permission still opens everything it should elsewhere.
      expect(am.mayOpen(perms: const ['employees.view']), isTrue);
    });

    test('deny does not catch somebody who merely holds the permission', () {
      final manager = user(roles: ['manager'], perms: ['employees.view']);

      expect(
        manager.mayOpen(
          roles: const ['super-admin', 'hr-admin', 'manager'],
          perms: const ['employees.view'],
          deny: const ['account-manager'],
        ),
        isTrue,
      );
    });
  });

  group('a permission for your own record is not a grant over everyone', () {
    // The employee role on this system carries payroll.view,
    // performance.view and performance.review so somebody can open their OWN
    // payslip and their OWN scorecard. Reading those as a right over the
    // administrative screens put a Payroll entry in front of all 1,247 staff
    // on the web, and the drawer carried the same mapping. These pin the
    // corrected rule: a module is opened by the permission that ADMINISTERS
    // it, never by the one that lets somebody look at their own.
    test('payroll.view does not open the payroll module', () {
      final staff = user(roles: ['employee'], perms: ['payroll.view']);

      expect(
        staff.mayOpen(
          roles: const ['super-admin', 'hr-admin', 'payroll-officer'],
          perms: const ['payroll.manage', 'payroll.approve', 'payroll.process'],
        ),
        isFalse,
      );
    });

    test('but payroll.manage does', () {
      final officer = user(roles: ['employee'], perms: ['payroll.manage']);

      expect(
        officer.mayOpen(
          roles: const ['super-admin', 'hr-admin', 'payroll-officer'],
          perms: const ['payroll.manage', 'payroll.approve', 'payroll.process'],
        ),
        isTrue,
      );
    });

    test('performance.view does not open Appraisals', () {
      final staff = user(
        roles: ['employee'],
        perms: ['performance.view', 'performance.review'],
      );

      expect(
        staff.mayOpen(
          roles: const ['super-admin', 'hr-admin', 'manager'],
          perms: const ['performance.manage'],
        ),
        isFalse,
      );
    });
  });

  group('can / canAny', () {
    test('they read the permissions the server sent', () {
      final u = user(perms: ['employees.view', 'leave.approve']);

      expect(u.can('employees.view'), isTrue);
      expect(u.can('employees.edit'), isFalse);
      expect(u.canAny(['employees.edit', 'leave.approve']), isTrue);
      expect(u.canAny(const []), isFalse);
    });

    test('a sign-in response with no permissions key does not throw', () {
      final u = UserModel.fromJson({
        'id': 2,
        'name': 'Older Build',
        'email': 'old@mastermindconsults.co.ug',
        'roles': ['employee'],
      });

      expect(u.permissions, isEmpty);
      expect(u.can('employees.view'), isFalse);
      expect(u.mayOpen(roles: const ['employee']), isTrue);
    });
  });
}
