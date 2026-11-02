import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/meal_comparison_bar.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../domain/models/extended_carb_plan_context.dart';

class BeforeMealEcarbsCard extends StatelessWidget {
  const BeforeMealEcarbsCard({super.key, required this.plans});
  final List<ExtendedCarbPlanContext>? plans;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    String time(DateTime at) =>
        DateFormat('HH:mm', lang.localeName).format(at.toLocal());
    return SummaryDetailCard(
      title: lang.beforeMealEcarbs,
      icon: Icons.schedule_rounded,
      explanation: plans?.isNotEmpty == true
          ? lang.beforeMealScheduleOnly
          : null,
      child: plans == null
          ? Text(lang.beforeMealUnavailable)
          : plans!.isEmpty
          ? Text(lang.beforeMealNoEcarbs)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final plan in plans!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${time(plan.treatment.createdAt)}–${time(plan.endsAt)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        MealComparisonBar(
                          label: lang.beforeMealRemaining,
                          valueLabel:
                              '${number.format(plan.scheduledAfterCutoffGrams)} / ${number.format(plan.treatment.carbs)} g',
                          value: plan.scheduledAfterCutoffGrams,
                          maximum: plan.treatment.carbs.toDouble(),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
