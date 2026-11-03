import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/status_info_card.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../common/widgets/connected_status_cards.dart';
import '../../common/widgets/status_info_panel.dart';
import '../../data/providers/linked_target_meal_provider.dart';
import '../controllers/dashboard_status_controller.dart';
import 'dashboard_target_actions.dart';
import 'dashboard_target_progress.dart';
import 'meal_target_picker_sheet.dart';

class DashboardMealTargetCard extends ConsumerWidget {
  const DashboardMealTargetCard({
    super.key,
    required this.target,
    required this.now,
  });

  final TemporaryTarget target;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meal = ref.watch(linkedTargetMealProvider(target)).asData?.value;
    final actions = DashboardTargetActions(
      target: target,
      attachTooltip: meal == null
          ? context.lang.dashboardAttachMeal
          : context.lang.dashboardChangeLinkedMeal,
      onAttach: () async {
        final id = await showMealTargetPickerSheet(
          context,
          target,
          selectedMealId: meal?.id,
        );
        if (id != null && context.mounted) {
          await ref
              .read(dashboardStatusControllerProvider.notifier)
              .attachMeal(target, id);
        }
      },
    );
    return ConnectedStatusCards(
      primary: StatusInfoCard(
        icon: Icons.restaurant_rounded,
        title: meal?.name ?? context.lang.dashboardMealTempTargetTitle,
        subtitle: meal == null
            ? context.lang.dashboardTargetValue(target.targetTop)
            : TimeOfDay.fromDateTime(
                DateTime.fromMillisecondsSinceEpoch(meal.plannedAt).toLocal(),
              ).format(context),
        details: meal == null
            ? DashboardTargetProgress(target: target, now: now)
            : null,
        trailing: meal == null ? actions : null,
      ),
      secondary: meal == null
          ? null
          : StatusInfoPanel(
              icon: Icons.track_changes_rounded,
              trailing: actions,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.lang.dashboardMealTempTargetTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    context.lang.dashboardTargetValue(target.targetTop),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DashboardTargetProgress(target: target, now: now),
                ],
              ),
            ),
    );
  }
}
