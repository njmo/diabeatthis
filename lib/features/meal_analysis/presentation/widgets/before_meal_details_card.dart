import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../domain/models/before_meal_context.dart';

class BeforeMealDetailsCard extends StatelessWidget {
  const BeforeMealDetailsCard({super.key, required this.data});
  final BeforeMealContext data;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    final colors = Theme.of(context).colorScheme;
    final basal = data.basal;
    String units(double? value) => value == null
        ? lang.beforeMealUnavailable
        : '${number.format(value)} U';
    String time(DateTime at) =>
        DateFormat('HH:mm', lang.localeName).format(at.toLocal());
    return SummaryDetailCard(
      title: lang.mealBeforeInsulinAndPod,
      icon: Icons.tune_rounded,
      explanation: lang.beforeMealReconstruction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${time(data.asOf.subtract(data.windows.insulin))}–${time(data.asOf)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ResponsiveMetricList(
            maxColumns: 2,
            minimumWidth: 120,
            children: [
              NutritionSummaryMetric(
                label: lang.dayRecordedBoluses,
                value: units(data.boluses?.units),
                icon: Icons.water_drop_outlined,
                color: colors.primary,
              ),
              NutritionSummaryMetric(
                label: lang.dayBasalTitle,
                value: units(
                  basal != null && basal.coveredDuration > Duration.zero
                      ? basal.units
                      : null,
                ),
                icon: Icons.show_chart_rounded,
                color: colors.secondary,
              ),
              NutritionSummaryMetric(
                label: lang.beforeMealPod,
                value: data.podAge == null
                    ? lang.beforeMealUnavailable
                    : '${data.podAge!.inDays} d ${data.podAge!.inHours.remainder(24)} h',
                icon: Icons.schedule_rounded,
                color: colors.primary,
              ),
            ],
          ),
          if (basal != null && basal.coveredDuration > Duration.zero) ...[
            const SizedBox(height: 10),
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
