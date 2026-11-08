import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/model/glucose.dart';
import '../../l10n/language.dart';
import '../../widgets/glucose_direction_icon.dart';
import '../../widgets/nutrition_summary_metric.dart';
import '../../widgets/responsive_metric_list.dart';

/// Shared presentation for real caregiver context and explicitly simulated data.
class MealDecisionContextMetrics extends StatelessWidget {
  const MealDecisionContextMetrics({
    super.key,
    this.glucose,
    this.iob,
    this.cob,
    this.delta,
  });
  final Glucose? glucose;
  final double? iob, cob;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern(context.lang.localeName);
    final color = Theme.of(context).colorScheme.primary;
    return ResponsiveMetricList(
      minimumWidth: 95,
      spacing: 8,
      runSpacing: 8,
      equalRowHeights: true,
      children: [
        NutritionSummaryMetric(
          label: context.lang.mealReviewGlucose,
          value: glucose == null ? '—' : number.format(glucose!.sgv),
          icon: iconForDirection(glucose?.direction),
          color: color,
          detail: delta == null
              ? null
              : context.lang.mealDecisionDemoDelta(
                  '${delta! > 0 ? '+' : ''}${number.format(delta)}',
                ),
        ),
        NutritionSummaryMetric(
          label: '${context.lang.dashboardIobLabel} · U',
          value: iob == null || !iob!.isFinite ? '—' : number.format(iob),
          icon: Icons.water_drop_outlined,
          color: color,
        ),
        NutritionSummaryMetric(
          label: '${context.lang.dashboardCobLabel} · g',
          value: cob == null || !cob!.isFinite ? '—' : number.format(cob),
          icon: Icons.grass_outlined,
          color: color,
        ),
      ],
    );
  }
}
