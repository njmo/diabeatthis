import 'package:diabeatthis/common/history/glucose_window_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_review_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';

void main() {
  for (final gap in [false, true]) {
    testWidgets(
      'coverage message distinguishes sampling phase from a gap: $gap',
      (tester) async {
        final start = DateTime(2026, 11, 2, 12);
        final summary = GlucoseWindowSummary(
          start: start,
          end: start.add(const Duration(minutes: 30)),
          readings: [
            for (var minute = 0; minute < 30; minute += 5)
              if (!gap || minute != 15)
                Glucose(
                  externalId: null,
                  source: GlucoseSource.cloud,
                  date: start.add(Duration(minutes: minute, seconds: 30)),
                  sgv: 100,
                  direction: 'Flat',
                ),
          ],
        );
        expect(
          summary.missing,
          gap
              ? const Duration(minutes: 5, seconds: 30)
              : const Duration(seconds: 30),
        );
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MealReviewSummary(summary: summary),
              ),
            ),
          ),
        );
        expect(
          find.textContaining('obraz posiłku jest niepełny'),
          gap ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
