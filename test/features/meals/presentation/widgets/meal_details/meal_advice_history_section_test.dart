import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_advice_history_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';
import 'meal_low_treatments_display_test.dart' show mealDetailsWithLowTreatment;

void main() {
  testWidgets('missing history and eating time remain explicitly unknown', (
    tester,
  ) async {
    final details = mealDetailsWithLowTreatment().copyWith(statusHistory: []);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealAdviceHistorySection(details: details, analysis: null),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Porada a zapisane zdarzenia'));
    await tester.pumpAndSettle();
    expect(find.text('Nieznany'), findsOneWidget);
    expect(find.text('Historia nie jest jeszcze dostępna.'), findsOneWidget);
    expect(
      find.textContaining('Czas wpisania węglowodanów nie zastępuje'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
