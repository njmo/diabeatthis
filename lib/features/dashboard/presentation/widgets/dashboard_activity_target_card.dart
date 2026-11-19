import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/status_info_card.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../controllers/dashboard_status_controller.dart';
import 'activity_target_attachment_sheet.dart';
import 'dashboard_target_actions.dart';
import 'dashboard_target_progress.dart';

class DashboardActivityTargetCard extends ConsumerWidget {
  const DashboardActivityTargetCard({
    super.key,
    required this.target,
    required this.now,
    this.allowLocalActions = true,
    required this.canAttach,
  });
  final TemporaryTarget target;
  final DateTime now;
  final bool allowLocalActions;
  final bool canAttach;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StatusInfoCard(
    icon: Icons.track_changes_rounded,
    title: context.lang.dashboardActivityTempTargetTitle,
    subtitle: target.targetBottom == target.targetTop
        ? context.lang.dashboardTargetValue(target.targetTop)
        : context.lang.caregiverTargetRange(
            target.targetBottom.toString(),
            target.targetTop.toString(),
          ),
    details: DashboardTargetProgress(target: target, now: now),
    trailing: !allowLocalActions
        ? null
        : DashboardTargetActions(
            target: target,
            attachTooltip: context.lang.dashboardAttachActivity,
            onAttach: !canAttach
                ? null
                : () async {
                    final draft = await showActivityTargetAttachmentSheet(
                      context,
                    );
                    if (draft == null || !context.mounted) return;
                    await ref
                        .read(dashboardStatusControllerProvider.notifier)
                        .attachActivity(target, draft);
                  },
          ),
  );
}
