import 'package:diabeatthis/common/family_sync/presentation/models/family_meal_details.dart';
import 'package:diabeatthis/common/presentation/details/meal_preview_controller.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page_body.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_charts_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_low_treatments_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_observation_context.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_macros.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_preview_actions.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_review_summary.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meals_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'family_collection_fixtures.dart';

void main() {
  for (final fullWindow in [false, true]) {
    testWidgets(
      'caregiver uses shared factual chart without local actions: full=$fullWindow',
      (tester) async {
        final saved = familySnapshotFixture();
        (saved['payload'] as Map)['snapshot_type'] = 'consumed';
        final base = FamilyMealDetails(
          familyCollectionFixtures(status: 'eaten')..add(saved),
        ).build(2, 'portion')!;
        final time = DateTime.fromMillisecondsSinceEpoch(familyRecordTime);
        final end = time.add(const Duration(hours: 1));
        final data = MealAnalysisData(
          chartStart: time,
          chartEnd: end,
          expectedChartEnd: fullWindow
              ? end
              : end.add(const Duration(hours: 1)),
          eventStart: time,
          eventEnd: end,
          mealTime: time,
          glucoseReadings: const [],
          treatments: [
            ManualBolus(externalId: 'bolus', createdAt: time, insulin: 2.5),
          ],
          temporaryTargets: const [],
          deviceStatuses: const [],
          linkedActivities: const [],
          linkedMeals: const [],
          timelineEvents: const [],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(
                (_) => throw StateError('local patient database accessed'),
              ),
            ],
            child: localizedMaterialApp(
              home: Scaffold(
                body: MealPageBody.controlled(
                  controller: CaregiverMealPreviewController(
                    base.copyWith(analysis: data),
                    showAnalysis: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MealReviewSummary), findsOneWidget);
        expect(find.byType(MealChartsSection), findsOneWidget);
        expect(find.byType(MealObservationContext), findsOneWidget);
        expect(find.text('2,5 U'), findsOneWidget);
        expect(find.byType(MealLowTreatmentsSection), findsNothing);
        expect(find.byType(MealPreviewActions), findsNothing);
        expect(find.byType(SimilarMealsSection), findsNothing);
        await tester.drag(find.byType(MealPageBody), const Offset(-600, 0));
        await tester.pumpAndSettle();
        final macros = tester.widget<MealPortionMacros>(
          find.byType(MealPortionMacros),
        );
        expect(macros.nutrition.totalNetCarbsG, 4);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
