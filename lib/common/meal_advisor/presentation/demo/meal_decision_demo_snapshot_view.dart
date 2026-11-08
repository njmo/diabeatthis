import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/model/glucose.dart';
import '../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../l10n/language.dart';
import '../../../widgets/meal_start/meal_start_nutrition.dart';
import '../../../widgets/section_surface.dart';
import '../../demo/meal_decision_demo_snapshot.dart';
import '../meal_decision_context_metrics.dart';
import '../meal_decision_context_status.dart';
import 'meal_decision_demo_glucose_history.dart';

class MealDecisionDemoSnapshotView extends StatelessWidget {
  const MealDecisionDemoSnapshotView({
    super.key,
    required this.snapshot,
    this.compact = false,
  });
  final MealDecisionDemoSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern(context.lang.localeName);
    final metrics = MealDecisionContextMetrics(
      glucose: Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: snapshot.capturedAt,
        sgv: snapshot.glucose,
        direction: snapshot.direction,
      ),
      iob: snapshot.iob,
      cob: snapshot.cob,
      delta: snapshot.delta,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionSurface(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact)
                MealDecisionDemoGlucoseHistory(
                  snapshot: snapshot,
                  leading: metrics,
                )
              else ...[
                MealDecisionContextStatus(
                  syncedAt: snapshot.capturedAt,
                  glucoseAt: snapshot.capturedAt,
                  iobAt: snapshot.capturedAt,
                  cobAt: snapshot.capturedAt,
                  referenceTime: snapshot.capturedAt,
                ),
                const SizedBox(height: 12),
                metrics,
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.lang.mealDecisionDemoMealValues,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        MealStartNutrition(
          carbsGrams: snapshot.carbs,
          extendedCarbsGrams: snapshot.extendedCarbs,
          scheduleSettings: const ExtendedCarbsScheduleSettings.defaults(),
        ),
        const SizedBox(height: 8),
        Text(
          context.lang.mealDecisionDemoMacros(
            number.format(snapshot.protein),
            number.format(snapshot.fat),
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
