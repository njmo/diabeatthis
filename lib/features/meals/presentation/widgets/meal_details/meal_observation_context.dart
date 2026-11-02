import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_formatters.dart';

class MealObservationContext extends StatelessWidget {
  final MealAnalysisData analysis;
  const MealObservationContext({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final outcome = analysis.outcomeContext;
    final basal = outcome?.basal;
    final number = NumberFormat('0.##', lang.localeName);
    final colors = Theme.of(context).colorScheme;
    return SummaryDetailCard(
      title: lang.mealObservationInsulin,
      icon: Icons.water_drop_outlined,
      explanation: lang.beforeMealReconstruction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${mealDateTime(outcome?.mealTime ?? analysis.eventStart)} – ${mealDateTime(outcome?.observedUntil ?? analysis.eventEnd)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ResponsiveMetricList(
            maxColumns: 2,
            minimumWidth: 120,
            children: [
              NutritionSummaryMetric(
                label: lang.dayRecordedBoluses,
                value:
                    '${number.format(outcome?.boluses.units ?? analysis.totalInsulinUnits)} U',
                icon: Icons.water_drop_outlined,
                color: colors.primary,
              ),
              NutritionSummaryMetric(
                label: lang.dayBasalTitle,
                value: basal == null || basal.coveredDuration == Duration.zero
                    ? lang.beforeMealUnavailable
                    : '${number.format(basal.units)} U',
                icon: Icons.show_chart_rounded,
                color: colors.secondary,
              ),
            ],
          ),
          if (basal != null && basal.coveredDuration > Duration.zero) ...[
            const SizedBox(height: 8),
            Text(
              '${lang.dayBasalCoverage}: ${number.format(basal.coverage * 100)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
