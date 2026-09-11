import 'package:diabeatthis/common/history/glucose_rise_summary.dart';
import 'package:diabeatthis/common/history/glucose_window_summary.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meals/common/formatters/format_meal_rise_timing.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_range_summary.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meal_glucose_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'build_meal_outcome_context_use_case_test.dart' show at, outcome;
import 'meal_glucose_test_helpers.dart';

void main() {
  Glucose sample(int minute) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: at(minute),
    sgv: 120,
    direction: 'Flat',
  );
  testWidgets(
    'both views use observed time for range percentages and retain missing time',
    (tester) async {
      final data = outcome(
        elapsed: 30,
        glucose: [sample(0), sample(5), sample(10)],
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MealRangeSummary(summary: data.glucoseSummary.window),
                  SimilarMealGlucoseSummary(data: glucosePreview(data)),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('70–180: 100%'), findsOneWidget);
      expect(find.text('Brak: 50%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('only complete coverage allows a negative rise result', () {
    final messages = AppLocalizationsPl();
    for (final hasGap in [false, true]) {
      final window = GlucoseWindowSummary(
        readings: [sample(0), sample(5), sample(10), if (!hasGap) sample(15)],
        start: at(0),
        end: at(20),
      );
      final rise = GlucoseRiseSummary.fromReadings(window.readings);
      for (final complete in [false, true]) {
        expect(
          formatMealRiseAbsence(rise, window, messages, complete: complete),
          complete && !hasGap
              ? messages.mealResponseNoRise
              : messages.mealResponseMissing,
        );
      }
    }
  });
}
