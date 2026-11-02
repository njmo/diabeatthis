import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../domain/models/before_meal_context.dart';
import 'before_meal_activity_card.dart';
import 'before_meal_ecarbs_card.dart';
import 'before_meal_lows_card.dart';
import 'prior_meal_card.dart';

class BeforeMealContextCards extends StatelessWidget {
  const BeforeMealContextCards({super.key, required this.data});
  final BeforeMealContext data;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final previous = data.precedingMeal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryDetailCard(
          title: lang.beforeMealPrecedingMeal,
          icon: Icons.restaurant_rounded,
          child: previous == null
              ? Text(
                  data.priorMeals == null
                      ? lang.beforeMealUnavailable
                      : lang.beforeMealNoPrecedingMeal(
                          formatDurationLabel(
                            BeforeMealContext.precedingMealWindow,
                          ),
                        ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.beforeMealSincePreviousMeal(
                        formatDurationLabel(
                          data.asOf.difference(previous.eatenAt),
                        ),
                      ),
                    ),
                    PriorMealCard(meal: previous),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        BeforeMealEcarbsCard(plans: data.extendedCarbPlans),
        const SizedBox(height: 12),
        BeforeMealLowsCard(treatments: data.lowTreatments),
        const SizedBox(height: 12),
        BeforeMealActivityCard(data: data),
      ],
    );
  }
}
