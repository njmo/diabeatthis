import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../domain/models/before_meal_context.dart';
import '../controllers/before_meal_target_controller.dart';

class BeforeMealTargetCard extends StatelessWidget {
  const BeforeMealTargetCard({super.key, required this.data});
  final BeforeMealContext data;

  @override
  Widget build(BuildContext context) {
    const controller = BeforeMealTargetController();
    final entry = controller.build(data);
    final lang = context.lang;
    if (entry == null) {
      return const SizedBox.shrink();
    }
    final target = entry.target;
    final targetType = controller.type(target);
    final time = DateFormat('d.MM HH:mm', lang.localeName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SummaryDetailCard(
        title: targetType == null
            ? lang.mealPrecedingTarget
            : '${lang.mealPrecedingTarget} · ${targetType == 'Meal' ? lang.mealTargetTypeMeal : lang.mealTargetTypeActivity}',
        explanation: targetType == null ? null : lang.mealTargetInferred,
        icon: Icons.track_changes,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NutritionSummaryMetric(
              label: lang.historyTemporaryTarget,
              value: target.targetBottom == target.targetTop
                  ? lang.mealTargetValue(target.targetBottom)
                  : lang.mealTargetRangeValue(
                      target.targetBottom,
                      target.targetTop,
                    ),
              icon: Icons.track_changes,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              '${time.format(target.createdAt.toLocal())} – ${time.format(entry.end.toLocal())}',
            ),
            const SizedBox(height: 4),
            Text(
              entry.active
                  ? lang.mealTargetActiveAtStart
                  : lang.mealTargetEndedBefore(
                      formatDurationLabel(data.asOf.difference(entry.end)),
                    ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
