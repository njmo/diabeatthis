import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_calculator_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  for (final grams in [10, 11]) {
    testWidgets('calculator hint is visible only above 10g: $grams', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(body: LowTreatmentCalculatorHint(carbs: grams)),
        ),
      );
      expect(
        find.byIcon(Icons.calculate_outlined),
        grams > 10 ? findsOneWidget : findsNothing,
      );
    });
  }
}
