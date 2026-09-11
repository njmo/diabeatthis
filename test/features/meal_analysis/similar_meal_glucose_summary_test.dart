import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meal_glucose_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'build_meal_outcome_context_use_case_test.dart' show at, outcome;
import 'meal_glucose_test_helpers.dart';

Glucose sample(int minutes, int value) => Glucose(
  externalId: null,
  source: GlucoseSource.cloud,
  date: at(minutes),
  sgv: value,
  direction: 'Flat',
  type: GlucoseType.cgm,
);

void main() {
  testWidgets('range percentages include gaps and rise is not the peak time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = outcome(
      elapsed: 30,
      glucose: [
        sample(0, 60),
        sample(5, 100),
        sample(10, 150),
        sample(15, 200),
      ],
    );
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              child: SimilarMealGlucoseSummary(data: glucosePreview(data)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Śr. 127,5 mg/dl'), findsOneWidget);
    expect(find.text('Max 200 mg/dl'), findsOneWidget);
    expect(find.text('Brak: 33,3%'), findsOneWidget);
    expect(find.textContaining('Wzrost: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'missing readings show unknown stats rather than a healthy response',
    (tester) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SimilarMealGlucoseSummary(data: glucosePreview(outcome())),
          ),
        ),
      );
      expect(find.text('Śr. — mg/dl'), findsOneWidget);
      expect(find.text('Max — mg/dl'), findsOneWidget);
      expect(find.text('Wzrost: —'), findsOneWidget);
      expect(find.text('Brak: 100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
