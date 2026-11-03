import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../activity/common/controllers/activity_actions_controller.dart';
import '../../common/utils/run_dashboard_status_action.dart';
import '../../domain/use_cases/stop_dashboard_target_use_case.dart';
import '../controllers/dashboard_status_controller.dart';

class DashboardTargetActions extends ConsumerWidget {
  const DashboardTargetActions({
    super.key,
    required this.target,
    this.onAttach,
    this.attachTooltip,
  });
  final TemporaryTarget target;
  final Future<void> Function()? onAttach;
  final String? attachTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(dashboardTargetControlEnabledProvider);
    final busy =
        ref.watch(dashboardStatusControllerProvider).isLoading ||
        ref.watch(activityActionsControllerProvider).isLoading;
    if (!enabled && onAttach == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onAttach != null)
          IconButton(
            tooltip: attachTooltip,
            icon: const Icon(Icons.link_rounded),
            onPressed: busy
                ? null
                : () => runDashboardStatusAction(context, onAttach!),
          ),
        if (enabled)
          IconButton(
            tooltip: context.lang.dashboardStopTarget,
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: busy
                ? null
                : () => runDashboardStatusAction(context, () async {
                    final result = await ref
                        .read(dashboardStatusControllerProvider.notifier)
                        .stopTarget(target);
                    if (!context.mounted ||
                        result == DashboardTargetActionResult.sent) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result == DashboardTargetActionResult.changed
                              ? context.lang.dashboardTargetChanged
                              : context.lang.dashboardTargetActionFailed,
                        ),
                      ),
                    );
                  }),
          ),
      ],
    );
  }
}
