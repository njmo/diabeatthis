import 'package:flutter/material.dart';

import '../../core/domain/model/glucose.dart';
import '../l10n/language.dart';
import 'glucose_direction_icon.dart';
import 'nutrition_summary_metric.dart';

class GlucoseSummaryMetric extends StatelessWidget {
  const GlucoseSummaryMetric({super.key, required this.glucose, this.detail});
  final Glucose? glucose;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final direction = glucose?.direction;
    final knownDirection = const [
      'DoubleUp',
      'SingleUp',
      'FortyFiveUp',
      'DoubleDown',
      'SingleDown',
      'FortyFiveDown',
      'Flat',
    ].contains(direction);
    return NutritionSummaryMetric(
      label: lang.mealReviewGlucose,
      value: glucose == null ? '—' : '${glucose!.sgv} mg/dl',
      icon: glucose == null
          ? Icons.bloodtype_outlined
          : iconForDirection(direction),
      color: Theme.of(context).colorScheme.primary,
      detail: glucose == null
          ? lang.mealReviewNoNearbyReading
          : [
              if (detail != null) detail!,
              if (!knownDirection) lang.mealReviewUnknownTrend,
            ].join('\n'),
    );
  }
}
