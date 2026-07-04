import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/notifications_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = notificationsAsync.valueOrNull?.unreadCount ?? 0;

    if (user == null) return const SizedBox.shrink();

    final navItems = _buildNavItems(user);
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return _MobileShell(
        navItems: navItems,
        user: user,
        unreadCount: unreadCount,
        child: widget.child,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: _sidebarCollapsed ? 68 : 240,
            child: _Sidebar(
              collapsed: _sidebarCollapsed,
              navItems: navItems,
              user: user,
              onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(user: user, unreadCount: unreadCount, onNotificationsTap: () => _showNotifications(context)),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _buildNavItems(user) {
    final items = <dynamic>[];
    items.add(_NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'));

    if (user.isClient) {
      items.add(_NavItem(icon: Icons.task_alt_rounded, label: 'Leave Approvals', path: '/client/leaves'));
      items.add(_NavItem(icon: Icons.people_alt_rounded, label: 'Recruitment', path: '/client/recruitment'));
      return items;
    }

    items.add(_NavSectionHeader('MY WORK'));
    items.add(_NavItem(icon: Icons.fingerprint_rounded, label: 'Attendance', path: '/attendance'));
    items.add(_NavItem(icon: Icons.beach_access_rounded, label: 'My Leave', path: '/leaves'));
    items.add(_NavItem(icon: Icons.receipt_long_rounded, label: 'My Payslips', path: '/my-payslips'));
    items.add(_NavItem(icon: Icons.folder_rounded, label: 'My Documents', path: '/my-documents'));
    items.add(_NavItem(icon: Icons.school_rounded, label: 'Training', path: '/training'));
    items.add(_NavItem(icon: Icons.balance_rounded, label: 'My Appraisal', path: '/bsc/my-appraisal'));
    items.add(_NavItem(icon: Icons.calendar_month_rounded, label: 'Meetings', path: '/meetings'));

    if (user.isAccountManager) {
      items.add(_NavSectionHeader('AM TOOLS'));
      items.add(_NavItem(icon: Icons.location_on_rounded, label: 'Site Visits', path: '/am-visits'));
      items.add(_NavItem(icon: Icons.people_rounded, label: 'Employees', path: '/am-employees'));
      items.add(_NavItem(icon: Icons.beach_access_rounded, label: 'Leave Management', path: '/am-leaves'));
      items.add(_NavItem(icon: Icons.payments_rounded, label: 'Payroll Runs', path: '/am-payroll'));
      items.add(_NavItem(icon: Icons.money_rounded, label: 'Salary Payments', path: '/am-salary-payments'));
      items.add(_NavItem(icon: Icons.balance_rounded, label: 'Team BSC', path: '/bsc'));
    }

    if (user.isAdmin || user.isManager) {
      items.add(_NavSectionHeader('MANAGEMENT'));
      items.add(_NavItem(icon: Icons.people_rounded, label: 'Employees', path: '/employees'));
      items.add(_NavItem(icon: Icons.bar_chart_rounded, label: 'Performance', path: '/performance'));
      items.add(_NavItem(icon: Icons.balance_rounded, label: 'BSC Appraisals', path: '/bsc'));
      if (user.canSeeProbation)
        items.add(_NavItem(icon: Icons.person_search_rounded, label: 'Probation', path: '/probation'));
    }

    if (user.isAdmin || user.isPayroll) {
      items.add(_NavSectionHeader('PAYROLL'));
      items.add(_NavItem(icon: Icons.payments_rounded, label: 'Payroll Runs', path: '/payroll'));
    }

    if (user.isAdmin || user.isRecruiter) {
      items.add(_NavSectionHeader('RECRUITMENT'));
      items.add(_NavItem(icon: Icons.work_rounded, label: 'Jobs', path: '/recruitment/jobs'));
      items.add(_NavItem(icon: Icons.person_search_rounded, label: 'Candidates', path: '/recruitment/candidates'));
      items.add(_NavItem(icon: Icons.record_voice_over_rounded, label: 'Interviews', path: '/recruitment/interviews'));
    }

    if (user.isAdmin || user.isManager || user.isPayroll) {
      items.add(_NavSectionHeader('ANALYTICS'));
      items.add(_NavItem(icon: Icons.insert_chart_rounded, label: 'Reports', path: '/reports'));
    }

    if (user.isAdmin) {
      items.add(_NavSectionHeader('ADMIN'));
      items.add(_NavItem(icon: Icons.manage_accounts_rounded, label: 'Users', path: '/admin/users'));
      items.add(_NavItem(icon: Icons.corporate_fare_rounded, label: 'Departments', path: '/admin/departments'));
      items.add(_NavItem(icon: Icons.business_center_rounded, label: 'Clients', path: '/admin/clients'));
      items.add(_NavItem(icon: Icons.history_rounded, label: 'Audit Logs', path: '/admin/audit'));
    }

    return items;
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _NotificationsSheet(),
    );
  }
}

// ─────────────── MOBILE SHELL ───────────────
class _MobileShell extends ConsumerStatefulWidget {
  final List<dynamic> navItems;
  final dynamic user;
  final int unreadCount;
  final Widget child;

  const _MobileShell({
    required this.navItems,
    required this.user,
    required this.unreadCount,
    required this.child,
  });

  @override
  ConsumerState<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<_MobileShell> {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final user = widget.user;

    // Bottom nav items based on role
    final List<_BottomNavItem> bottomItems = _getBottomNavItems(user);
    final currentIndex = _getCurrentIndex(location, bottomItems);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _MobileAppBar(user: user, unreadCount: widget.unreadCount, location: location),
      drawer: _MobileDrawer(navItems: widget.navItems, user: user),
      body: widget.child,
      bottomNavigationBar: bottomItems.length > 1
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) => context.go(bottomItems[i].path),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              indicatorColor: AppColors.infoLight,
              destinations: bottomItems.map((item) => NavigationDestination(
                icon: Icon(item.icon, color: AppColors.textSecondary),
                selectedIcon: Icon(item.icon, color: AppColors.primary),
                label: item.label,
              )).toList(),
            )
          : null,
    );
  }

  List<_BottomNavItem> _getBottomNavItems(user) {
    if (user.isClient) {
      return [
        _BottomNavItem(icon: Icons.task_alt_rounded, label: 'Leaves', path: '/client/leaves'),
        _BottomNavItem(icon: Icons.people_alt_rounded, label: 'Recruitment', path: '/client/recruitment'),
      ];
    }
    if (user.isAdmin) {
      return [
        _BottomNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'),
        _BottomNavItem(icon: Icons.people_rounded, label: 'Employees', path: '/employees'),
        _BottomNavItem(icon: Icons.fingerprint_rounded, label: 'Attendance', path: '/attendance'),
        _BottomNavItem(icon: Icons.payments_rounded, label: 'Payroll', path: '/payroll'),
        _BottomNavItem(icon: Icons.more_horiz_rounded, label: 'More', path: '/profile'),
      ];
    }
    if (user.isAccountManager) {
      return [
        _BottomNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'),
        _BottomNavItem(icon: Icons.location_on_rounded, label: 'Site Visits', path: '/am-visits'),
        _BottomNavItem(icon: Icons.people_rounded, label: 'Employees', path: '/am-employees'),
        _BottomNavItem(icon: Icons.beach_access_rounded, label: 'Leaves', path: '/am-leaves'),
        _BottomNavItem(icon: Icons.person_rounded, label: 'Profile', path: '/profile'),
      ];
    }
    if (user.isRecruiter) {
      return [
        _BottomNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'),
        _BottomNavItem(icon: Icons.work_rounded, label: 'Jobs', path: '/recruitment/jobs'),
        _BottomNavItem(icon: Icons.person_search_rounded, label: 'Candidates', path: '/recruitment/candidates'),
        _BottomNavItem(icon: Icons.record_voice_over_rounded, label: 'Interviews', path: '/recruitment/interviews'),
      ];
    }
    return [
      _BottomNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'),
      _BottomNavItem(icon: Icons.fingerprint_rounded, label: 'Attendance', path: '/attendance'),
      _BottomNavItem(icon: Icons.beach_access_rounded, label: 'Leave', path: '/leaves'),
      _BottomNavItem(icon: Icons.receipt_long_rounded, label: 'Payslips', path: '/my-payslips'),
      _BottomNavItem(icon: Icons.person_rounded, label: 'Profile', path: '/profile'),
    ];
  }

  int _getCurrentIndex(String location, List<_BottomNavItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].path)) return i;
    }
    return 0;
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;
  final String path;
  const _BottomNavItem({required this.icon, required this.label, required this.path});
}

class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic user;
  final int unreadCount;
  final String location;
  const _MobileAppBar({required this.user, required this.unreadCount, required this.location});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Image.asset('assets/images/logo.jpg', height: 28, fit: BoxFit.contain),
          const SizedBox(width: 8),
          Text(_titleFor(location), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => const _NotificationsSheet(),
              ),
              icon: const Icon(Icons.notifications_outlined),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _titleFor(String location) {
    const titles = {
      '/dashboard': 'Dashboard',
      '/attendance': 'Attendance',
      '/leaves': 'Leave',
      '/my-payslips': 'My Payslips',
      '/my-documents': 'My Documents',
      '/payroll': 'Payroll',
      '/employees/': 'Employee Details',
      '/employees': 'Employees',
      '/recruitment/jobs': 'Jobs',
      '/recruitment/candidates': 'Candidates',
      '/recruitment/interviews': 'Interviews',
      '/performance': 'Performance',
      '/training': 'Training',
      '/meetings': 'Meetings',
      '/reports': 'Reports',
      '/profile': 'My Profile',
      '/admin/users': 'Users',
      '/admin/departments': 'Departments',
      '/admin/clients': 'Clients',
      '/admin/audit': 'Audit Logs',
      '/client/dashboard': 'Client Portal',
      '/client/leaves': 'Leave Approvals',
      '/client/recruitment': 'Recruitment',
      '/am-visits': 'Site Visits',
      '/am-employees': 'Employees',
      '/am-leaves': 'Leave Management',
      '/am-payroll': 'Payroll Runs',
      '/am-salary-payments': 'Salary Payments',
      '/bsc/my-appraisal': 'My Appraisal',
      '/bsc': 'BSC Appraisals',
      '/probation': 'Probation Tracking',
    };
    for (final e in titles.entries) {
      if (location.startsWith(e.key)) return e.value;
    }
    return 'Mastermind HRMS';
  }
}

// ─────────────── MOBILE DRAWER ───────────────
class _MobileDrawer extends ConsumerWidget {
  final List<dynamic> navItems;
  final dynamic user;
  const _MobileDrawer({required this.navItems, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final initials = user.name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      child: Column(
        children: [
          // Header
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/logo.jpg', height: 44, fit: BoxFit.contain, alignment: Alignment.centerLeft),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary,
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                            Text(user.email, style: const TextStyle(color: AppColors.sidebarText, fontSize: 11), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: navItems.map((item) {
                if (item is _NavSectionHeader) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(item.title, style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  );
                }
                if (item is _NavItem) {
                  final isActive = location == item.path || location.startsWith('${item.path}/');
                  return ListTile(
                    dense: true,
                    leading: Icon(item.icon, color: isActive ? Colors.white : AppColors.sidebarText, size: 20),
                    title: Text(item.label, style: TextStyle(color: isActive ? Colors.white : AppColors.sidebarText, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400, fontSize: 14)),
                    tileColor: isActive ? AppColors.sidebarActive : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    horizontalTitleGap: 8,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(item.path);
                    },
                  );
                }
                return const SizedBox.shrink();
              }).toList(),
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFFC4E4E), size: 20),
              title: const Text('Sign Out', style: TextStyle(color: Color(0xFFFC4E4E), fontSize: 14, fontWeight: FontWeight.w500)),
              onTap: () {
                // Show dialog while drawer is still mounted so ref stays valid
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(ctx);           // close dialog
                          Navigator.pop(context);       // close drawer
                          ref.read(authProvider.notifier).logout(); // GoRouter handles redirect
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── DESKTOP SIDEBAR ───────────────
class _Sidebar extends ConsumerWidget {
  final bool collapsed;
  final List<dynamic> navItems;
  final dynamic user;
  final VoidCallback onToggle;

  const _Sidebar({required this.collapsed, required this.navItems, required this.user, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    return Container(
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Logo
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 16),
            child: Row(
              children: [
                if (collapsed)
                  Expanded(
                    child: Center(
                      child: Image.asset('assets/images/logo.jpg', height: 36, fit: BoxFit.contain),
                    ),
                  )
                else ...[
                  Expanded(
                    child: Image.asset('assets/images/logo.jpg', height: 40, fit: BoxFit.contain, alignment: Alignment.centerLeft),
                  ),
                  GestureDetector(
                    onTap: onToggle,
                    child: Icon(Icons.chevron_left, color: AppColors.sidebarText, size: 20),
                  ),
                ],
                if (collapsed)
                  GestureDetector(
                    onTap: onToggle,
                    child: const Icon(Icons.chevron_right, color: AppColors.sidebarText, size: 20),
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: navItems.map((item) {
                if (item is _NavSectionHeader) {
                  if (collapsed) return const SizedBox(height: 8);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(item.title, style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  );
                }
                if (item is _NavItem) {
                  final isActive = location == item.path || location.startsWith('${item.path}/');
                  return _SidebarTile(item: item, isActive: isActive, collapsed: collapsed, onTap: () => context.go(item.path));
                }
                return const SizedBox.shrink();
              }).toList(),
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          _SidebarUserTile(user: user, collapsed: collapsed, ref: ref),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;
  const _SidebarTile({required this.item, required this.isActive, required this.collapsed, required this.onTap});

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? AppColors.sidebarActive
        : _hovered ? const Color(0xFF1E293B) : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.collapsed ? widget.item.label : '',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: widget.collapsed
                ? Center(child: Icon(widget.item.icon, color: widget.isActive ? Colors.white : AppColors.sidebarText, size: 20))
                : Row(children: [
                    Icon(widget.item.icon, color: widget.isActive ? Colors.white : AppColors.sidebarText, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.item.label, style: TextStyle(color: widget.isActive ? Colors.white : AppColors.sidebarText, fontSize: 13.5, fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400))),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _SidebarUserTile extends StatelessWidget {
  final dynamic user;
  final bool collapsed;
  final WidgetRef ref;
  const _SidebarUserTile({required this.user, required this.collapsed, required this.ref});

  @override
  Widget build(BuildContext context) {
    final initials = user.name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        padding: EdgeInsets.all(collapsed ? 12 : 16),
        child: collapsed
            ? Center(child: CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))))
            : Row(children: [
                CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text(user.roles.isNotEmpty ? _roleLabel(user.roles.first) : 'User', style: const TextStyle(color: AppColors.sidebarText, fontSize: 11)),
                ])),
                Tooltip(
                  message: 'Sign Out',
                  child: GestureDetector(
                    onTap: () => _confirmLogout(context),
                    child: const Icon(Icons.logout_rounded, color: Color(0xFFFC4E4E), size: 16),
                  ),
                ),
              ]),
      ),
    );
  }

  String _roleLabel(String role) {
    const map = {'super-admin': 'Super Admin', 'hr-admin': 'HR Admin', 'payroll-officer': 'Payroll Officer', 'recruiter': 'Recruiter', 'manager': 'Manager', 'employee': 'Employee', 'client': 'Client'};
    return map[role] ?? role;
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              ref.read(authProvider.notifier).logout(); // GoRouter handles redirect
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ─────────────── DESKTOP TOP BAR ───────────────
class _TopBar extends StatelessWidget {
  final dynamic user;
  final int unreadCount;
  final VoidCallback onNotificationsTap;
  const _TopBar({required this.user, required this.unreadCount, required this.onNotificationsTap});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final title = _titleFor(location);
    return Container(
      height: 64,
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: onNotificationsTap,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
                  child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textSecondary),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 4, top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(unreadCount > 9 ? '9+' : '$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Row(children: [
              CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Text(user.name.split(' ').first, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
            ]),
          ),
        ],
      ),
    );
  }

  String _titleFor(String location) {
    const titles = {'/dashboard': 'Dashboard', '/attendance': 'Attendance', '/leaves': 'Leave Management', '/my-payslips': 'My Payslips', '/my-documents': 'My Documents', '/payroll': 'Payroll', '/employees/': 'Employee Details', '/employees': 'Employees', '/recruitment/jobs': 'Jobs', '/recruitment/candidates': 'Candidates', '/recruitment/interviews': 'Interviews', '/performance': 'Performance', '/training': 'Training', '/meetings': 'Meetings', '/reports': 'Reports', '/profile': 'My Profile', '/admin/users': 'Users', '/admin/departments': 'Departments', '/admin/clients': 'Clients', '/admin/audit': 'Audit Logs', '/client/dashboard': 'Client Dashboard', '/client/leaves': 'Leave Approvals', '/client/recruitment': 'Recruitment Approvals', '/am-visits': 'Site Visits', '/bsc/my-appraisal': 'My BSC Appraisal', '/bsc': 'BSC Appraisals', '/probation': 'Probation Tracking'};
    for (final e in titles.entries) { if (location.startsWith(e.key)) return e.value; }
    return 'Mastermind HRMS';
  }
}

// ─────────────── NOTIFICATIONS SHEET ───────────────
class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(notificationsProvider.notifier).markAllRead();
                  Navigator.pop(context);
                },
                child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const Divider(),
          notificationsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (data) {
              if (data.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.notifications_none_rounded, size: 40, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text('No notifications', style: TextStyle(color: AppColors.textMuted)),
                  ]),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView(
                  shrinkWrap: true,
                  children: data.items.take(10).map((n) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: n.read ? Colors.transparent : AppColors.primary),
                    ),
                    title: Text(n.title, style: TextStyle(fontSize: 13, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                    subtitle: Text(n.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(n.timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  )).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────── NAV TYPES ───────────────
class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem({required this.icon, required this.label, required this.path});
}

class _NavSectionHeader {
  final String title;
  const _NavSectionHeader(this.title);
}
