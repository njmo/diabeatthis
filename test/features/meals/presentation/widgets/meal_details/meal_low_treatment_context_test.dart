import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_low_treatment_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';

void main() {
  final adviceAt = DateTime(2026, 9, 10, 12);
  for (final scenario in ['empty', 'unavailable', 'unlinked']) {
    testWidgets('analysis context distinguishes $scenario history', (
      tester,
    ) async {
      final analysis = scenario == 'unavailable'
          ? null
          : MealAnalysisData(
              chartStart: adviceAt,
              chartEnd: adviceAt.add(const Duration(hours: 2)),
              expectedChartEnd: adviceAt.add(const Duration(hours: 2)),
              eventStart: adviceAt.subtract(const Duration(hours: 1)),
              eventEnd: adviceAt.add(const Duration(hours: 2)),
              mealTime: adviceAt,
              glucoseReadings: [],
              treatments: [],
              temporaryTargets: [],
              deviceStatuses: [],
              linkedActivities: [],
              linkedMeals: [],
              timelineEvents: [],
              lowTreatments: scenario == 'empty'
                  ? []
                  : [
                      RecordedLowTreatment(
                        mealId: 1,
                        eatenAt: adviceAt.subtract(const Duration(minutes: 20)),
                        netCarbsGrams: 10,
                        suggestedCarbs: 12,
                        reason: LowTreatmentReason.plannedActivity,
                      ),
                      RecordedLowTreatment(
                        mealId: 2,
                        eatenAt: adviceAt.add(const Duration(minutes: 30)),
                        netCarbsGrams: 8,
                        reason: LowTreatmentReason.lowGlucose,
                      ),
                    ],
            );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealLowTreatmentContext(
                adviceAt: adviceAt,
                analysis: analysis,
              ),
            ),
          ),
        ),
      );
      if (scenario == 'unavailable') {
        expect(
          find.text('Historia dosłodzeń nie jest jeszcze dostępna.'),
          findsOneWidget,
        );
        expect(
          find.text('Brak zapisanych dosłodzeń w tym oknie.'),
          findsNothing,
        );
      } else if (scenario == 'empty') {
        expect(
          find.text('Brak zapisanych dosłodzeń w tym oknie.'),
          findsOneWidget,
        );
      } else {
        expect(
          find.textContaining('Zapisane spożycie: 10g netto'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Zapisane spożycie: 8g netto'),
          findsOneWidget,
        );
        expect(find.textContaining('Propozycja AAPS: 12g'), findsOneWidget);
        expect(find.textContaining('Planowana aktywność'), findsOneWidget);
        expect(
          find.textContaining('Obecność zdarzenia w tym oknie'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
