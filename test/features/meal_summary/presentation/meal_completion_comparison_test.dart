import 'package:diabeatthis/common/meal/meal_extended_carbs.dart';
import 'package:diabeatthis/common/widgets/meal_comparison_bar.dart';
import 'package:diabeatthis/common/widgets/value_comparison_bars.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_nutrition_comparison.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_review.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  Future<ProviderContainer> load(List<MealIngredientsDraft> items) async {
    final container = ProviderContainer(
      overrides: [
        getMealByIdProvider(1).overrideWith(
          (ref) async => const Meal(id: 1, name: 'Lunch', status: 'eating'),
        ),
        getMealIngredientsDraftForMealProvider(
          1,
        ).overrideWith((ref) async => items),
      ],
    );
    final subscription = container.listen(
      mealSummaryControllerProvider(1),
      (_, _) {},
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    await container.read(mealSummaryControllerProvider(1).future);
    return container;
  }

  MealSummaryDraft draft(ProviderContainer container) =>
      container.read(mealSummaryControllerProvider(1)).requireValue;

  test(
    'half of the live draft halves mass and every macro while preserving plan',
    () async {
      final container = await load([comparisonIngredient(1)]);
      container
          .read(mealSummaryControllerProvider(1).notifier)
          .setReportedPortionFactor(0.5);
      final result = calculateMealSummaryNutritionComparison(draft(container));
      expect(result.hasKnownMass, isTrue);
      expect(result.planned.totalGrams, 100);
      expect(result.consumed.totalGrams, 50);
      expect(result.planned.carbsGrams, 30);
      expect(result.consumed.carbsGrams, 15);
      expect(result.planned.netCarbsGrams, 25);
      expect(result.consumed.netCarbsGrams, 12.5);
      expect(result.planned.fatGrams, 20);
      expect(result.consumed.fatGrams, 10);
      expect(result.planned.proteinGrams, 10);
      expect(result.consumed.proteinGrams, 5);
      expect(result.consumed.fiberGrams, 2.5);
      expect(mealExtendedCarbsFromMacros(result.planned), 22);
      expect(mealExtendedCarbsFromMacros(result.consumed), 11);
    },
  );

  test(
    'mixed grams, named portions, and reference portions keep independent conversions',
    () async {
      final container = await load([
        comparisonIngredient(1, consumed: 25),
        comparisonIngredient(2, amount: 2, consumed: 1, portionGrams: 30),
        comparisonIngredient(
          3,
          amount: 2,
          consumed: 0.5,
          portionGrams: 30,
          reference: true,
        ),
      ]);
      var result = calculateMealSummaryNutritionComparison(draft(container));
      expect(result.planned.totalGrams, 360);
      expect(result.consumed.totalGrams, 105);
      expect(result.planned.netCarbsGrams, 90);
      expect(result.consumed.netCarbsGrams, 26.25);
      expect(result.consumed.fatGrams, 21);
      expect(result.consumed.proteinGrams, 10.5);
      container
          .read(mealSummaryControllerProvider(1).notifier)
          .setConsumedAmount(3, 1);
      result = calculateMealSummaryNutritionComparison(draft(container));
      expect(result.consumed.totalGrams, 155);
      expect(result.consumed.fatGrams, 31);
      expect(result.planned.totalGrams, 360);
    },
  );

  test(
    'saved and newly added products contribute zero to the original plan',
    () async {
      final container = await load([
        comparisonIngredient(1, consumed: 50),
        comparisonIngredient(2, amount: 20, consumed: 20, extra: true),
      ]);
      final controller = container.read(
        mealSummaryControllerProvider(1).notifier,
      );
      controller.addExtraItem(
        comparisonIngredient(
          3,
          amount: 1.5,
          consumed: 1.5,
          portionGrams: 40,
          extra: true,
        ),
      );
      final result = calculateMealSummaryNutritionComparison(draft(container));
      expect(draft(container).itemsById[2]!.isExtra, isTrue);
      expect(result.planned.totalGrams, 100);
      expect(result.planned.netCarbsGrams, 25);
      expect(result.consumed.totalGrams, 130);
      expect(result.consumed.netCarbsGrams, 32.5);
      expect(result.consumed.fatGrams, 26);
      expect(result.consumed.proteinGrams, 13);
    },
  );

  testWidgets(
    'review reuses plan versus eaten bars and reacts to edits without duplicate products',
    (tester) async {
      final container = await load([comparisonIngredient(1)]);
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Consumer(
                  builder: (context, ref, _) => MealCompletionReview(
                    draft: ref
                        .watch(mealSummaryControllerProvider(1))
                        .requireValue,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Product 1'), findsNothing);
      expect(find.byType(ValueComparisonBars), findsNWidgets(5));
      expect(find.byType(MealComparisonBar), findsNWidgets(10));
      expect(find.text('Zaplanowane'), findsNWidgets(5));
      expect(find.text('Zjedzone'), findsNWidgets(5));
      final before = tester
          .widgetList<ValueComparisonBars>(find.byType(ValueComparisonBars))
          .toList();
      expect(before.first.firstValue, 100);
      expect(before.first.secondValue, 100);
      container
          .read(mealSummaryControllerProvider(1).notifier)
          .setReportedPortionFactor(0.5);
      await tester.pumpAndSettle();
      final after = tester
          .widgetList<ValueComparisonBars>(find.byType(ValueComparisonBars))
          .toList();
      expect(after.first.firstValue, 100);
      expect(after.first.secondValue, 50);
      expect(after.last.firstValue, 22);
      expect(after.last.secondValue, 11);
      expect(tester.takeException(), isNull);
    },
  );
}

MealIngredientsDraft comparisonIngredient(
  int id, {
  double amount = 100,
  double? consumed,
  double? portionGrams,
  bool reference = false,
  bool extra = false,
}) => MealIngredientsDraft(
  mealIngredientId: id,
  ingredient: IngredientDraft.existing(
    id: id,
    name: 'Product $id',
    carbsPer100g: 30,
    fatPer100g: 20,
    fiberPer100g: 5,
    proteinPer100g: 10,
    nutritionConfidence: 1,
    isReference: reference,
    carbsLabelMode: CarbsLabelMode.nonEu,
  ),
  ingredientPortion: IngredientPortionDraft(
    portion: portionGrams == null
        ? const PortionSelection.empty()
        : const PortionSelection.existing(id: 1, name: 'slice', unitHint: 'g'),
    amount: portionGrams ?? 1,
  ),
  amount: amount,
  quantityConfidence: 1,
  entryType: extra ? 'extra' : 'planned',
  consumedAmount: consumed ?? amount,
  consumedConfidence: 1,
);
