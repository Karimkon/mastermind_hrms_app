import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/supervisor_model.dart';
import '../../core/providers/supervisor_provider.dart';
import '../../core/widgets/ui.dart';

/// Everything this supervisor has asked for, and what came of it.
///
/// Worth its own screen because a supervisor cannot withdraw a request: once
/// sent, the only thing they can do is see where it got to. Without this they
/// would have no way of knowing whether anybody had looked — and the next
/// step after "nobody looked" is asking somebody to change it by hand.
class SupervisorRequestsScreen extends ConsumerWidget {
  const SupervisorRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supervisorRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('My change requests')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(supervisorRequestsProvider),
        child: async.when(
          loading: () => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpace.md),
                child: SkeletonBox(height: 92, radius: AppRadius.lg),
              ),
            ),
          ),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(AppSpace.page(context)),
            children: [
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load your requests',
                detail: e.toString().replaceFirst('Exception: ', ''),
                action: FilledButton(
                  onPressed: () => ref.invalidate(supervisorRequestsProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
          data: (requests) => requests.isEmpty
              ? ListView(
                  padding: EdgeInsets.all(AppSpace.page(context)),
                  children: const [
                    EmptyState(
                      icon: Icons.fact_check_rounded,
                      title: 'You have not asked for any changes',
                      detail: 'Open somebody in your workforce to update their '
                          'details. The account manager decides each request.',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: EdgeInsets.all(AppSpace.page(context)),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                  itemBuilder: (_, i) => _RequestCard(request: requests[i]),
                ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final PendingChangeModel request;
  const _RequestCard({required this.request});

  (String, Color, IconData) get _state {
    if (request.isApproved) {
      return ('Approved', AppColors.success, Icons.check_circle_rounded);
    }
    if (request.isRejected) {
      return ('Declined', AppColors.error, Icons.cancel_rounded);
    }
    return ('Waiting', AppColors.warning, Icons.hourglass_bottom_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = _state;

    return AppCard(
      accent: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  request.label ?? 'A change request',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Flexible(child: AppChip(label: label, tone: tone, icon: icon)),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            [
              if ((request.client ?? '').isNotEmpty) request.client!,
              if (request.fields.isNotEmpty)
                '${request.fields.length} '
                    '${request.fields.length == 1 ? 'detail' : 'details'}',
              if ((request.requestedAt ?? '').isNotEmpty)
                'sent ${request.requestedAt!.split(' ').first}',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),

          // The reason a decline was a decline. Without it the supervisor
          // sends the same correction again next week.
          if ((request.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '${request.reviewedBy ?? 'The account manager'}: ${request.reviewNote}',
                style: const TextStyle(
                    fontSize: 12, height: 1.45, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
