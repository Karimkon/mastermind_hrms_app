import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Where a tap should take you, and whether you can get back.
///
/// The app used `context.go()` almost everywhere. go() REPLACES the whole
/// route stack, so a drill-down left nothing behind it: open a screen from the
/// dashboard, press the phone's back button, and the app closed rather than
/// returning. Every screen reached from a card, a "View all" link or a quick
/// action behaved that way.
///
/// push() is right for a drill-down, because it stacks. go() stays right for
/// switching bottom-navigation tabs, where stacking would pile up duplicate
/// copies of the same tab and make back walk through a history nobody built on
/// purpose.
///
/// So the destination decides, not the call site -- which is the only way this
/// stays correct as screens are added.
class AppNav {
  const AppNav._();

  /// Every path used as a bottom-navigation destination, across all roles.
  ///
  /// Roles see different bars, so this is the union: a path that is a tab for
  /// anybody is treated as a tab. Being wrong in this direction costs a lost
  /// back entry on a screen that already has a tab; being wrong the other way
  /// stacks duplicate tabs.
  static const Set<String> tabPaths = {
    '/dashboard',
    '/employees',
    '/attendance',
    '/payroll',
    '/profile',
    '/am-visits',
    '/am-employees',
    '/am-leaves',
    '/leaves',
    '/my-payslips',
    '/client/leaves',
    '/client/recruitment',
    '/recruitment/jobs',
    '/recruitment/candidates',
    '/recruitment/interviews',
  };

  static bool isTab(String path) => tabPaths.contains(path.split('?').first);

  /// Open [path], keeping a way back unless it is a tab.
  static void open(BuildContext context, String path) {
    if (isTab(path)) {
      context.go(path);
    } else {
      context.push(path);
    }
  }
}
