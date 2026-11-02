import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_ecarbs_card.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_lows_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('empty history is stated specifically inside the cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                BeforeMealEcarbsCard(plans: []),
                BeforeMealLowsCard(treatments: []),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Brak trwających harmonogramów eCarbs.'), findsOneWidget);
    expect(
      find.text('Brak zapisanych dosłodzeń przed posiłkiem.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable history is not reported as an empty history', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                BeforeMealEcarbsCard(plans: null),
                BeforeMealLowsCard(treatments: null),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Brak trwających harmonogramów eCarbs.'), findsNothing);
    expect(
      find.text('Brak zapisanych dosłodzeń przed posiłkiem.'),
      findsNothing,
    );
    expect(find.text('Brak danych'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
