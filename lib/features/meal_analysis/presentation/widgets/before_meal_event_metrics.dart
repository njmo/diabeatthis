import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../domain/models/before_meal_context.dart';

class BeforeMealEventMetrics extends StatelessWidget {
  final BeforeMealContext data;
  final bool showMealCount;
  final bool showActivityCount;
  const BeforeMealEventMetrics({
    super.key,
    required this.data,
    this.showMealCount = true,
    this.showActivityCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.#', lang.localeName);
    final plans = data.extendedCarbPlans;
    final remaining = plans?.fold(
      0.0,
      (sum, plan) => sum + plan.scheduledAfterCutoffGrams,
    );
    return ResponsiveMetricList(
      maxColumns: 2,
      minimumWidth: 130,
      children: [
        if (showMealCount)
          AnalysisMetric(
            icon: Icons.restaurant,
            label: lang.beforeMealPreviousMeals,
            value: data.priorMeals?.length.toString() ?? '—',
          ),
        AnalysisMetric(
          icon: Icons.cake_outlined,
          label: lang.beforeMealLows,
          value: data.lowTreatments?.length.toString() ?? '—',
        ),
        if (showActivityCount)
          AnalysisMetric(
            icon: Icons.directions_run,
            label: lang.beforeMealActivities,
            value: data.activities?.length.toString() ?? '—',
          ),
        AnalysisMetric(
          icon: Icons.schedule,
          label: lang.beforeMealEcarbs,
          value: remaining == null ? '—' : '${number.format(remaining)} g',
          detail: lang.beforeMealRemaining,
        ),
      ],
    );
  }
}
