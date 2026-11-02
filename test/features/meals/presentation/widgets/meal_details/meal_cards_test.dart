import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/data/providers/similar_meals_provider.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_glucose_card.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../../helpers/localized_material_app.dart';
import 'meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment, mealRecord;
import 'meal_review_test.dart' show ReviewTestController;

MealSnapshotDetailsData cardSnapshot(String type, double carbs, double grams) =>
    MealSnapshotDetailsData(
      id: type == 'planned' ? 1 : 2,
      mealId: 1,
      snapshotType: type,
      totalGrams: grams,
      totalCarbsG: carbs,
      totalFiberG: 2,
      totalNetCarbsG: carbs - 2,
      totalFatG: 7.5,
      totalProteinG: 10,
      totalCaloriesKcal: 300,
      ingredientsCount: 1,
      avgQuantityConfidence: null,
      minQuantityConfidence: null,
      carbWeightedQuantityConfidence: null,
      wbtWeightedQuantityConfidence: null,
      carbWeightedNutritionConfidence: null,
      wbtWeightedNutritionConfidence: null,
      carbWeightedEffectiveConfidence: null,
      wbtWeightedEffectiveConfidence: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      isSynced: false,
    );

void main() {
  Future<void> showPortion(WidgetTester tester, MealDetailsData details) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MealPortionCard(details: details)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'portion card shows actual macros and plan markers without expansion',
    (tester) async {
      await showPortion(
        tester,
        mealDetailsWithLowTreatment().copyWith(
          plannedSnapshot: cardSnapshot('planned', 50, 250),
          consumedSnapshot: cardSnapshot('consumed', 62, 300),
        ),
      );
      expect(find.text('Porcja i makro'), findsOneWidget);
      expect(find.text('62 g'), findsOneWidget);
      expect(find.text('7,5 g'), findsOneWidget);
      expect(find.text('300 kcal'), findsOneWidget);
      expect(find.text('plan 50 g'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unconfirmed consumption remains explicitly planned', (
    tester,
  ) async {
    await showPortion(
      tester,
      mealDetailsWithLowTreatment().copyWith(
        plannedSnapshot: cardSnapshot('planned', 50, 250),
      ),
    );
    expect(find.text('Nie potwierdzono zjedzonej porcji'), findsOneWidget);
    expect(find.text('Poniższe wartości dotyczą planu.'), findsOneWidget);
    expect(find.textContaining('Zjedzono 100%'), findsNothing);
    expect(find.textContaining('→ zjedzono'), findsNothing);
  });

  testWidgets('zero consumed portion is not replaced by the plan', (
    tester,
  ) async {
    await showPortion(
      tester,
      mealDetailsWithLowTreatment().copyWith(
        plannedSnapshot: cardSnapshot('planned', 50, 250),
        consumedSnapshot: cardSnapshot('consumed', 0, 0),
      ),
    );
    expect(find.text('0 g'), findsOneWidget);
    expect(find.text('plan 50 g'), findsOneWidget);
    expect(find.textContaining('0 g'), findsWidgets);
  });

  for (final status in ['planned', 'skipped', 'interrupted']) {
    testWidgets('$status keeps the planned portion clearly labelled', (
      tester,
    ) async {
      final details = mealDetailsWithLowTreatment().copyWith(
        meal: mealRecord(
          id: 1,
          name: 'Test meal',
          plannedAt: DateTime(2026),
          status: status,
        ),
        plannedSnapshot: cardSnapshot('planned', 50, 250),
      );
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
      tester
          .widget<SwipeableCards>(find.byType(SwipeableCards))
          .controller
          .animateTo(1);
      await tester.pumpAndSettle();
      expect(find.text('Planowana porcja'), findsOneWidget);
      expect(find.byType(MealPortionCard), findsOneWidget);
      expect(find.byType(MealGlucoseCard), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'cards remain readable at $width with enlarged text and inline history action',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final fixture = await ReviewTestController().build(1);
        final details = fixture.details.copyWith(
          plannedSnapshot: cardSnapshot('planned', 50, 250),
          consumedSnapshot: cardSnapshot('consumed', 62, 300),
        );
        final state = MealPageState(
          details: details,
          analysis: fixture.analysis,
          usesLocalHistory: true,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              similarMealsProvider(details).overrideWith((ref) async => null),
            ],
            child: localizedMaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(body: MealPageBody(state: state)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Uzupełnij historię'), findsOneWidget);
        expect(
          tester.widget<SwipeableCards>(find.byType(SwipeableCards)).labels,
          hasLength(6),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
