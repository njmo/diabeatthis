import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_suggestion_comparison.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_suggestion_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  for (final scenario in [
    (carbs: 0, suggestion: 0, status: LowTreatmentSuggestionStatus.none),
    (carbs: 24, suggestion: 0, status: LowTreatmentSuggestionStatus.none),
    (carbs: 0, suggestion: 10, status: LowTreatmentSuggestionStatus.below),
    (carbs: 6, suggestion: 10, status: LowTreatmentSuggestionStatus.below),
    (carbs: 10, suggestion: 10, status: LowTreatmentSuggestionStatus.covered),
    (carbs: 19, suggestion: 10, status: LowTreatmentSuggestionStatus.covered),
    (carbs: 20, suggestion: 10, status: LowTreatmentSuggestionStatus.excess),
    (carbs: 24, suggestion: 10, status: LowTreatmentSuggestionStatus.excess),
  ]) {
    test(
      'coverage ${scenario.carbs}/${scenario.suggestion}: ${scenario.status}',
      () {
        final comparison = LowTreatmentSuggestionComparison(
          carbs: scenario.carbs,
          suggestedCarbs: scenario.suggestion,
        );
        expect(comparison.status, scenario.status);
        expect(
          comparison.difference,
          (scenario.carbs - scenario.suggestion).abs(),
        );
      },
    );
  }

  for (final carbs in [6, 12, 20, 24]) {
    testWidgets(
      'coverage message for $carbs g on a narrow screen with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          localizedMaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: LowTreatmentSuggestionStatusBanner(
                  comparison: LowTreatmentSuggestionComparison(
                    carbs: carbs,
                    suggestedCarbs: 10,
                  ),
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );
        expect(
          find.text('Sprawdź w AAPS, czy potrzebny jest bolus.'),
          carbs >= 20 ? findsOneWidget : findsNothing,
        );
        if (carbs == 6) {
          expect(find.text('Poniżej sugestii o 4 g'), findsOneWidget);
        }
        if (carbs == 12) expect(find.text('Sugestia pokryta'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
