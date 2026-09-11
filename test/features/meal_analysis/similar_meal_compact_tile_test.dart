import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meal_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'find_similar_meals_use_case_test.dart' show candidate;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('compact match fits 320px with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opened = false;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child: SimilarMealTile(
                  match: SimilarMealMatch(
                    meal: candidate(1),
                    distance: 0,
                    matchesIngredients: true,
                    portionRatio: 2,
                  ),
                  onTap: () => opened = true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Chip), findsNothing);
      expect(find.textContaining('200% porcji'), findsOneWidget);
      expect(find.text('WW netto 30 g'), findsOneWidget);
      if (scale == 1) {
        expect(tester.getSize(find.byType(ListTile)).height, lessThan(140));
      }
      await tester.tap(find.text('Meal 1'));
      expect(opened, true);
      expect(tester.takeException(), isNull);
    });
  }
}
