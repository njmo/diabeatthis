import 'package:diabeatthis/common/widgets/detail_section_card.dart';
import 'package:diabeatthis/features/meals/common/widgets/meal_macro_comparison.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/current_meal_macro_comparison.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meals_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';
import 'meal_low_treatments_display_test.dart' show mealDetailsWithLowTreatment;

void main() {
  final at = DateTime(2026, 9, 9, 20);
  final details = mealDetailsWithLowTreatment().copyWith(
    consumedSnapshot: MealSnapshotDetailsData(
      id: 1,
      mealId: 1,
      snapshotType: 'consumed',
      totalGrams: 100,
      totalCarbsG: 30,
      totalFiberG: 5,
      totalNetCarbsG: 25,
      totalFatG: 10,
      totalProteinG: 15,
      totalCaloriesKcal: 250,
      ingredientsCount: 3,
      avgQuantityConfidence: null,
      minQuantityConfidence: null,
      carbWeightedQuantityConfidence: null,
      wbtWeightedQuantityConfidence: null,
      carbWeightedNutritionConfidence: null,
      wbtWeightedNutritionConfidence: null,
      carbWeightedEffectiveConfidence: null,
      wbtWeightedEffectiveConfidence: null,
      createdAt: at,
      updatedAt: at,
      isSynced: true,
    ),
  );

  testWidgets(
    'basic mode shows a standalone macro card above similar meals; advanced hides it',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: localizedMaterialApp(
            home: Scaffold(
              body: MealPageBody(state: MealPageState(details: details)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final current = find.byType(CurrentMealMacroComparison);
      final similar = find.byType(SimilarMealsSection);
      expect(current, findsOneWidget);
      expect(
        find.descendant(of: current, matching: find.byType(DetailSectionCard)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: current, matching: find.text('WW netto 25 g')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: similar,
          matching: find.byType(MealMacroComparison),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(current).dy,
        lessThan(tester.getTopLeft(similar).dy),
      );

      await tester.tap(find.text('Zaawansowany'));
      await tester.pumpAndSettle();
      expect(current, findsNothing);
      expect(similar, findsOneWidget);
      await tester.tap(find.text('Podstawowy'));
      await tester.pumpAndSettle();
      expect(current, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing macro snapshot does not leave an empty card', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: CurrentMealMacroComparison(
            details: mealDetailsWithLowTreatment(),
          ),
        ),
      ),
    );
    expect(find.byType(DetailSectionCard), findsNothing);
  });
}
