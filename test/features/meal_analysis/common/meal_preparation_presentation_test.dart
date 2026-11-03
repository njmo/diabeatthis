import 'package:diabeatthis/common/widgets/timeline_analysis_charts.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/meal_analysis/common/widgets/meal_target_preparation_note.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/before_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/before_meal_windows.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_activity_context.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_absent_context_card.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_activity_card.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_context_cards.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  final at = DateTime(2026, 11, 3, 12);
  final target = TemporaryTarget(nightscoutId: 'preparation', createdAt: at.subtract(const Duration(minutes: 20)),
    durationInMiliseconds: 3600000, duration: 60, targetBottom: 90, targetTop: 90);
  BeforeMealContext contextData() => BeforeMealContext(asOf: at, builtAt: at, mealId: 1, macros: null,
    windows: const BeforeMealWindows(), glucose: [
      Glucose(externalId: 'first', source: GlucoseSource.cloud, date: at.subtract(const Duration(minutes: 20)), sgv: 120, direction: 'Flat'),
      Glucose(externalId: 'last', source: GlucoseSource.cloud, date: at, sgv: 110, direction: 'Flat'),
    ], glucoseSummary: null, latestDeviceStatus: null, predictions: null, basal: null, boluses: null,
    treatments: [target], extendedCarbPlans: const [], priorMeals: const [], lowTreatments: const [],
    activities: [MealActivityContext(logId: 7, name: 'Spacer', startedAt: at.subtract(const Duration(hours: 2)),
      endedAt: at.subtract(const Duration(hours: 1)), recordedAt: at.subtract(const Duration(hours: 2)),
      plannedDurationMinutes: 60, percentagePre: 80, percentagePost: 100)], podAge: null, failedSources: const {});

  testWidgets('preparation is marked on the chart and described below IOB and COB', (tester) async {
    await tester.pumpWidget(localizedMaterialApp(home: Scaffold(body: SingleChildScrollView(child: BeforeMealOverview(data: contextData(), hasRecordedStart: true)))));
    await tester.pumpAndSettle();
    expect(find.byType(MealTargetPreparationNote), findsOneWidget);
    final note = find.textContaining('Target Meal aktywny 20 min przed rozpoczęciem jedzenia');
    expect(note, findsOneWidget);
    expect(tester.getTopLeft(note).dy, greaterThan(tester.getBottomLeft(find.text('IOB')).dy));
    expect(tester.getTopLeft(note).dy, greaterThan(tester.getBottomLeft(find.text('COB')).dy));
    final charts = tester.widget<TimelineAnalysisCharts>(find.byType(TimelineAnalysisCharts));
    expect(charts.ranges.single.start, target.createdAt);
    expect(charts.ranges.single.end, at);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the activity and remaining context have a visible gap', (tester) async {
    await tester.pumpWidget(localizedMaterialApp(home: Scaffold(body: SingleChildScrollView(child: BeforeMealContextCards(data: contextData())))));
    await tester.pumpAndSettle();
    final activity = tester.getRect(find.byType(BeforeMealActivityCard));
    final absent = tester.getRect(find.byType(BeforeMealAbsentContextCard));
    expect(absent.top - activity.bottom, greaterThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
  });
}
