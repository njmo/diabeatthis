import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/providers/copied_meal_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/copied_meal_ingredients_preview.dart';
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

  testWidgets('returns from preview to the same query and scroll position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final meals = List.generate(
      30,
      (index) => CopiedMealFromMeal(
        id: index + 1,
        name: 'Obiad $index',
        date: DateTime(2026).subtract(Duration(days: index)),
        copiedFromMealId: null,
        copiedFromTemplateId: null,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        copiedFromMealByQueryProvider('Obiad').overrideWith((_) async => meals),
        for (final meal in meals)
          getMealIngredientsDraftForMealProvider(
            meal.id,
          ).overrideWith((_) async => []),
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
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    final offset = scrollable.position.pixels;
    final visibleMeal = find.textContaining('Obiad ').hitTestable().first;
    await tester.tap(visibleMeal);
    await tester.pumpAndSettle();
    expect(find.byType(CopiedMealIngredientsPreview), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Obiad',
    );
    expect(scrollable.position.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses the selected source from a narrow sheet with keyboard insets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final container = ProviderContainer(
        overrides: [
          copiedFromMealByQueryProvider('').overrideWith((_) async => [meal]),
          getMealIngredientsDraftForMealProvider(1).overrideWith(
            (ref) async => [ref.read(mealIngredientsDraftProvider)],
          ),
        ],
      );
      addTearDown(container.dispose);
      CopiedMealType? selected;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      selected = await showModalBottomSheet<CopiedMealType>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const CopiedMealPicker(),
                      ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(meal.name));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      await tester.tap(find.text('Użyj składników'));
      await tester.pumpAndSettle();
      expect(selected, same(meal));
      expect(tester.takeException(), isNull);
    },
  );

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
            body: CopiedMealIngredientsPreview(
              source: meal,
              onUse: () => selected++,
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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
            body: CopiedMealIngredientsPreview(
              source: meal,
              onUse: () => fail('Must not select'),
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
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
