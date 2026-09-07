import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/providers/copied_meal_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/copied_meal_picker.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  final meal = CopiedMealFromMeal(
    id: 1,
    name: 'Obiad z historii',
    date: DateTime(2026),
    copiedFromMealId: null,
    copiedFromTemplateId: null,
  );
  final template = CopiedMealFromTemplate(
    id: 2,
    name: 'Stary szablon',
    date: DateTime(2026),
    copiedFromMealId: null,
  );

  testWidgets('starts with meal history and keeps saved templates separately', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        copiedFromMealByQueryProvider(
          'Obiad',
        ).overrideWith((_) async => [meal]),
        copiedFromMealTemplateByQueryProvider(
          'Obiad',
        ).overrideWith((_) async => [template]),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: const Scaffold(body: CopiedMealPicker(initialQuery: 'Obiad')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(meal.name), findsOneWidget);
    expect(find.text(template.name), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Obiad',
    );
    await tester.tap(find.text('Zapisane szablony'));
    await tester.pumpAndSettle();
    expect(find.text(template.name), findsOneWidget);
    expect(find.text(meal.name), findsNothing);
  });

  testWidgets('preview does not mutate the draft or choose a source', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        getMealIngredientsDraftForMealProvider(1).overrideWith((ref) async {
          final draft = ref.read(mealIngredientsDraftProvider);
          return [
            draft.copyWith(
              ingredient: draft.ingredient.copyWith(name: 'Ryż'),
              ingredientPortion: const IngredientPortionDraft(
                portion: PortionSelection.empty(),
                amount: 1,
              ),
              amount: 150,
            ),
            draft.copyWith(
              ingredient: draft.ingredient.copyWith(name: 'Chleb'),
              ingredientPortion: const IngredientPortionDraft(
                portion: PortionSelection.draft(name: 'kromka', unitHint: 'g'),
                amount: 35,
              ),
              amount: 2,
            ),
            draft.copyWith(
              ingredient: draft.ingredient.copyWith(
                name: 'Zupa ref',
                isReference: true,
              ),
              ingredientPortion: const IngredientPortionDraft(
                portion: PortionSelection.empty(),
                amount: 100,
              ),
              amount: 0.5,
            ),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(mealDraftProvider, (_, _) {});
    addTearDown(subscription.close);
    final before = container.read(mealDraftProvider);
    var selected = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CopiedMealPickerTile(
                copiedMeal: meal,
                onPick: () => selected++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(meal.name));
    await tester.pumpAndSettle();
    expect(find.text('Użyj składników'), findsOneWidget);
    expect(find.textContaining('150 g'), findsOneWidget);
    expect(find.textContaining('2 kromka'), findsOneWidget);
    expect(find.textContaining('0,5 porcji'), findsOneWidget);
    expect(selected, 0);
    expect(container.read(mealDraftProvider), same(before));
    await tester.ensureVisible(find.text('Użyj składników'));
    await tester.tap(find.text('Użyj składników'));
    expect(selected, 1);
  });

  testWidgets('failed ingredient preview can retry before using ingredients', (
    tester,
  ) async {
    var shouldFail = true;
    final container = ProviderContainer(
      overrides: [
        getMealIngredientsDraftForMealProvider(1).overrideWith((ref) async {
          if (shouldFail) throw StateError('load failed');
          return [];
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Scaffold(
            body: CopiedMealPickerTile(
              copiedMeal: meal,
              onPick: () => fail('Must not select'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(meal.name));
    await tester.pumpAndSettle();
    expect(find.text('Użyj składników'), findsNothing);
    shouldFail = false;
    await tester.tap(find.text('Nie udało się wczytać. Spróbuj ponownie'));
    await tester.pumpAndSettle();
    expect(find.text('Brak składników do użycia.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
