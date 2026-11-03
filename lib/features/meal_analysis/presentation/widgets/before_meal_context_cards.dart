import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../domain/models/before_meal_context.dart';
import 'before_meal_absent_context_card.dart';
import 'before_meal_activity_card.dart';
import 'before_meal_ecarbs_card.dart';
import 'before_meal_lows_card.dart';
import 'before_meal_target_card.dart';
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
        BeforeMealTargetCard(data: data),
        if (previous != null)
          SummaryDetailCard(
            title: lang.beforeMealPrecedingMeal,
            icon: Icons.restaurant_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.beforeMealSincePreviousMeal(
                    formatDurationLabel(data.asOf.difference(previous.eatenAt)),
                  ),
                ),
                PriorMealCard(meal: previous),
              ],
            ),
          ),
        if (previous != null) const SizedBox(height: 12),
        if (data.extendedCarbPlans?.isNotEmpty == true)
          BeforeMealEcarbsCard(plans: data.extendedCarbPlans),
        if (data.extendedCarbPlans?.isNotEmpty == true)
          const SizedBox(height: 12),
        if (data.lowTreatments?.isNotEmpty == true)
          BeforeMealLowsCard(treatments: data.lowTreatments),
        if (data.lowTreatments?.isNotEmpty == true) const SizedBox(height: 12),
        if (data.recentPrecedingActivity != null) ...[
          BeforeMealActivityCard(data: data),
          const SizedBox(height: 12),
        ],
        BeforeMealAbsentContextCard(data: data),
      ],
    );
  }
}
