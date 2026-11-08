import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/model/glucose.dart';
import '../../../l10n/language.dart';
import '../../../widgets/timeline_analysis_charts.dart';
import '../../demo/meal_decision_demo_snapshot.dart';

/// Historical sample curves, independent of the current request and therapy state.
class MealDecisionDemoSimilarMeal extends StatelessWidget {
  const MealDecisionDemoSimilarMeal({
    super.key,
    required this.mealName,
    required this.snapshot,
    required this.daysAgo,
  });
  final String mealName;
  final MealDecisionDemoSnapshot snapshot;
  final int daysAgo;

  @override
  Widget build(BuildContext context) {
    final start = snapshot.capturedAt.subtract(Duration(days: daysAgo));
    final values = daysAgo == 1
        ? [105, 125, 148, 156, 140, 120, 108, 103, 100]
        : [110, 138, 175, 192, 184, 160, 135, 119, 110];
    return Card.outlined(
      child: ExpansionTile(
        title: Text(mealName),
        subtitle: Text(
          DateFormat('dd.MM HH:mm', context.lang.localeName).format(start),
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          Text(context.lang.mealDecisionDemoHistoricalCurve),
          TimelineAnalysisCharts(
            chartStart: start,
            chartEnd: start.add(const Duration(hours: 2)),
            fitToWidth: true,
            showDeviceMetrics: false,
            deviceStatuses: const [],
            glucoseReadings: [
              for (var i = 0; i < values.length; i++)
                Glucose(
                  externalId: null,
                  source: GlucoseSource.cloud,
                  date: start.add(Duration(minutes: i * 15)),
                  sgv: values[i],
                  direction: 'NONE',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
