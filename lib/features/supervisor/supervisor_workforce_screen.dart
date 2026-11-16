import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/supervisor_model.dart';
import '../../core/navigation/app_nav.dart';
import '../../core/providers/supervisor_provider.dart';
import '../../core/widgets/ui.dart';
import 'supervisor_dashboard_screen.dart' show NoPostingNotice;

/// Everyone placed at the supervised site.
///
/// The list is the supervisor's roll call, so each row answers the two
/// questions they actually have: who is this, and have they turned up.
class SupervisorWorkforceScreen extends ConsumerStatefulWidget {
  const SupervisorWorkforceScreen({super.key});

  @override
  ConsumerState<SupervisorWorkforceScreen> createState() =>
      _SupervisorWorkforceScreenState();
}

class _SupervisorWorkforceScreenState
    extends ConsumerState<SupervisorWorkforceScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Debounced, so a name typed at speed is one request rather than eight.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supervisorWorkforceProvider(_query));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.page(context),
              AppSpace.md,
              AppSpace.page(context),
              AppSpace.sm,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or staff number',
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _debounce?.cancel();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(supervisorWorkforceProvider(_query)),
              child: async.when(
                loading: () => ListView(
                  padding: EdgeInsets.all(AppSpace.page(context)),
                  children: List.generate(
                    6,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpace.md),
                      child: SkeletonBox(height: 78, radius: AppRadius.lg),
                    ),
                  ),
                ),
                error: (e, _) => e is NoPostingException
                    ? NoPostingNotice(message: e.message)
                    : ListView(
                        padding: EdgeInsets.all(AppSpace.page(context)),
                        children: [
                          EmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: 'Could not load your workforce',
                            detail: e.toString().replaceFirst('Exception: ', ''),
                            action: FilledButton(
                              onPressed: () => ref
                                  .invalidate(supervisorWorkforceProvider(_query)),
                              child: const Text('Try again'),
                            ),
                          ),
                        ],
                      ),
                data: (people) => people.isEmpty
                    ? ListView(
                        padding: EdgeInsets.all(AppSpace.page(context)),
                        children: [
                          EmptyState(
                            icon: Icons.groups_rounded,
                            title: _query.isEmpty
                                ? 'Nobody is placed here yet'
                                : 'Nobody matches "$_query"',
                            detail: _query.isEmpty
                                ? 'When staff are placed at your site they appear here.'
                                : 'Try a surname or a staff number.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          AppSpace.page(context),
                          AppSpace.sm,
                          AppSpace.page(context),
                          AppSpace.xxxl,
                        ),
                        itemCount: people.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpace.md),
                        itemBuilder: (_, i) => _PersonCard(person: people[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final SupervisorEmployeeModel person;
  const _PersonCard({required this.person});

  /// What today says about this person, in the colour it deserves.
  ///
  /// No record is NOT the same as absent, and colouring it red would accuse
  /// somebody of not turning up when the truth is that nobody has looked.
  (String, Color) get _today {
    final status = person.today?.status;

    return switch (status) {
      'present' => ('Present', AppColors.success),
      'late' => ('Late', AppColors.warning),
      'absent' => ('Absent', AppColors.error),
      'half_day' => ('Half day', AppColors.info),
      'leave' => ('On leave', AppColors.info),
      _ => ('Not recorded', AppColors.textMuted),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, tone) = _today;

    return AppCard(
      onTap: () => AppNav.open(context, '/supervisor/workforce/${person.id}'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.primaryTint,
            child: Text(
              _initials(person.name),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    person.staffNumber,
                    if ((person.designation ?? '').isNotEmpty) person.designation!,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                // Flexible inside its own Row: a Row hands a non-flex child
                // unbounded width, and "Not recorded" on a 320pt phone is
                // exactly the shape that overflows.
                Row(
                  children: [
                    Flexible(child: AppChip(label: label, tone: tone)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}
