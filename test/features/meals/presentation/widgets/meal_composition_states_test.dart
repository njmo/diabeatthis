import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_composition_step.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/copied_meal_source_card.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredients_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  final source = CopiedMealFromMeal(
    id: 9,
    name: 'Kolacja',
    date: DateTime(2026, 11, 2),
    copiedFromMealId: null,
    copiedFromTemplateId: null,
  );

  testWidgets('start choices become a list after adding the first ingredient', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(
            body: MealCompositionStep(
              picker: (_) async => null,
              onPicked: (_) async => true,
              isCopying: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Użyj wcześniejszego posiłku'), findsOneWidget);
    expect(find.byType(MealIngredientsList), findsNothing);
    container.read(mealDraftProvider.notifier).setMealIngredients([
      mealFlowIngredient(container),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Użyj wcześniejszego posiłku'), findsNothing);
    expect(find.byType(MealIngredientsList), findsOneWidget);
    expect(find.text('Dodaj składnik'), findsOneWidget);
    expect(find.text('Skopiuj z posiłku'), findsOneWidget);
  });

  testWidgets('copying into a populated list needs confirmation', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(mealDraftProvider.notifier).setMealIngredients([
      mealFlowIngredient(container),
    ]);
    var applied = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(
            body: MealCompositionStep(
              picker: (_) async => source,
              onPicked: (_) async {
                applied++;
                return true;
              },
              isCopying: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skopiuj z posiłku'));
    await tester.pumpAndSettle();
    expect(applied, 0);
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(applied, 0);
    expect(container.read(mealDraftProvider).mealIngredients, hasLength(1));
    await tester.tap(find.text('Skopiuj z posiłku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zastąp składniki'));
    await tester.pumpAndSettle();
    expect(applied, 1);
  });

  testWidgets('source stays visible after changing a copied portion', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ingredient = mealFlowIngredient(container);
    container.read(mealDraftProvider.notifier).setMealIngredients([ingredient]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(
            body: MealCompositionStep(
              picker: (_) async => null,
              onPicked: (_) async => true,
              isCopying: false,
              source: source,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(mealDraftProvider.notifier).setMealIngredients([
      ingredient.copyWith(amount: 150),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(CopiedMealSourceCard), findsOneWidget);
    expect(find.text('Skopiowano z: Kolacja'), findsOneWidget);
    expect(find.text('Zmień'), findsOneWidget);
    expect(find.text('Użyj wcześniejszego posiłku'), findsNothing);
    expect(find.text('Dodaj składnik'), findsOneWidget);
  });
}
