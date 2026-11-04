import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_overview.dart';
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

  testWidgets('macros appear only on the portion tab', (tester) async {
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
    expect(find.byType(MealPortionOverview), findsNothing);
    tester
        .widget<SwipeableCards>(find.byType(SwipeableCards))
        .controller
        .animateTo(1);
    await tester.pumpAndSettle();
    expect(find.byType(MealPortionOverview), findsOneWidget);
    expect(find.text('25,0 g'), findsOneWidget);
    expect(find.text('Węglowodany netto'), findsOneWidget);
    expect(find.text('250 kcal'), findsOneWidget);
    tester
        .widget<SwipeableCards>(find.byType(SwipeableCards))
        .controller
        .animateTo(0);
    await tester.pumpAndSettle();
    expect(find.byType(MealPortionOverview), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing macro snapshot is explicitly unconfirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: MealPortionOverview(details: mealDetailsWithLowTreatment()),
        ),
      ),
    );
    expect(find.text('250 kcal'), findsNothing);
    expect(find.text('Nie potwierdzono zjedzonej porcji'), findsOneWidget);
  });
}
