import 'package:diabeatthis/common/family_sync/presentation/family_meal_plan_form.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/planning/meal_ingredient_amount_sheet.dart';
import 'package:diabeatthis/common/planning/meal_ingredient_portion_choices.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_portion_data.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../family_sync/family_meal_plan_form_test.dart'
    show FamilyPlanTestCatalog;

void main() {
  testWidgets(
    'family portions keep frozen grams and convert without a local database',
    (tester) async {
      final original = MealIngredientsDraft(
        ingredient: const IngredientDraft.existing(
          id: 1,
          name: 'Bread',
          carbsPer100g: 40,
          fatPer100g: 2,
          fiberPer100g: 3,
          proteinPer100g: 8,
          nutritionConfidence: 1,
          isReference: false,
        ),
        ingredientPortion: const IngredientPortionDraft(
          portion: PortionSelection.existing(
            id: 1,
            name: 'Slice',
            unitHint: 'g',
          ),
          amount: 25,
        ),
        recordedGramsPerAmount: 25,
        amount: 4,
        quantityConfidence: 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );
      final portions = [
        IngredientPortionData(
          portionId: 1,
          name: 'Slice',
          unitHint: 'g',
          gramsPerPortion: 40,
        ),
        IngredientPortionData(
          portionId: 2,
          name: 'Roll',
          unitHint: 'g',
          gramsPerPortion: 50,
        ),
      ];
      MealIngredientsDraft? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('local database read'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      result = await showModalBottomSheet<MealIngredientsDraft>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => MealIngredientAmountSheet(
                          draft: original,
                          portions: portions,
                        ),
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
      expect(find.byType(MealIngredientPortionChoices), findsOneWidget);
      expect(find.text('25 g'), findsOneWidget);
      expect(
        tester
            .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
            .value,
        4,
      );
      await tester.tap(find.text('Roll'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
            .value,
        2,
      );
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      expect(result!.amount, 2);
      expect(result!.recordedGramsPerAmount, 50);
      expect(result!.amount * result!.recordedGramsPerAmount!, 100);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('family form uses shared portion and submits converted grams', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FamilyPlanTestCatalog()),
          databaseProvider.overrideWith(
            (_) => throw StateError('local database read'),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FamilyMealPlanForm(
              rows: [
                {
                  'kind': 'ingredients',
                  'id': '5',
                  'payload': {
                    'id': 5,
                    'name': 'Bread',
                    'is_reference': 0,
                    'carbs_per_100g': 40.0,
                    'fiber_per_100g': 3.0,
                    'protein_per_100g': 8.0,
                    'fat_per_100g': 2.0,
                    'nutrition_confidence': .8,
                    'carbs_label_mode': 'eu',
                  },
                },
                {
                  'kind': 'ingredientPortions',
                  'id': '5_2',
                  'payload': {
                    'ingredient_id': 5,
                    'portion_id': 2,
                    'grams_per_portion': 50.0,
                  },
                },
                {
                  'kind': 'portions',
                  'id': '2',
                  'payload': {'id': 2, 'name': 'Roll', 'unit_hint': 'g'},
                },
                {
                  'kind': 'ingredientPortions',
                  'id': '5_3',
                  'payload': {
                    'ingredient_id': 5,
                    'portion_id': 3,
                    'grams_per_portion': -1.0,
                  },
                },
                {
                  'kind': 'portions',
                  'id': '3',
                  'payload': {'id': 3, 'name': 'Invalid', 'unit_hint': 'g'},
                },
              ],
              initial: {
                'name': 'Lunch',
                'category': 'lunch',
                'plannedAt': DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch,
                'ingredients': [
                  {'ingredientId': 5, 'grams': 100.0},
                ],
              },
              onSubmit: (v) async => sent = v,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lang = AppLocalizations.of(
      tester.element(find.byType(FamilyMealPlanForm)),
    );
    await tester.tap(find.byTooltip(lang.mealEditIngredientTooltip));
    await tester.pumpAndSettle();
    expect(find.text('Invalid'), findsNothing);
    await tester.tap(find.text('Roll'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
          .value,
      2,
    );
    await tester.tap(find.text(lang.commonSave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(lang.mealFlowNextTime));
    await tester.pumpAndSettle();
    await tester.tap(find.text(lang.mealFlowNextReview));
    await tester.pumpAndSettle();
    await tester.tap(find.text(lang.mealFlowPlan));
    await tester.pumpAndSettle();
    expect(sent!['ingredients'], [
      {
        'ingredientId': 5,
        'catalogId': null,
        'catalogRevision': null,
        'grams': 100.0,
      },
    ]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'removed saved portion remains selectable with its frozen conversion',
    (tester) async {
      const draft = MealIngredientsDraft(
        ingredient: IngredientDraft.existing(
          id: 1,
          name: 'Bread',
          carbsPer100g: 40,
          fatPer100g: 2,
          fiberPer100g: 3,
          proteinPer100g: 8,
          nutritionConfidence: 1,
          isReference: false,
        ),
        ingredientPortion: IngredientPortionDraft(
          portion: PortionSelection.existing(
            id: 1,
            name: 'Slice',
            unitHint: 'g',
          ),
          amount: 25,
        ),
        recordedGramsPerAmount: 25,
        amount: 4,
        quantityConfidence: 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('local database read'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: MealIngredientAmountSheet(draft: draft)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Slice'), findsOneWidget);
      expect(find.text('25 g'), findsOneWidget);
      final selector = tester.widget<MealIngredientPortionChoices>(
        find.byType(MealIngredientPortionChoices),
      );
      selector.onSelected(null);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
            .value,
        100,
      );
      final updated = tester.widget<MealIngredientPortionChoices>(
        find.byType(MealIngredientPortionChoices),
      );
      updated.onSelected(updated.portions.single);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
            .value,
        4,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final example in [(100.0, 30.0), (1.0, 100.0)]) {
    testWidgets('precise conversion remains visible and editable: $example', (
      tester,
    ) async {
      final draft = MealIngredientsDraft(
        ingredient: const IngredientDraft.existing(
          id: 1,
          name: 'Bread',
          carbsPer100g: 40,
          fatPer100g: 2,
          fiberPer100g: 3,
          proteinPer100g: 8,
          nutritionConfidence: 1,
          isReference: false,
        ),
        ingredientPortion: const IngredientPortionDraft(
          portion: PortionSelection.empty(),
          amount: 1,
        ),
        recordedGramsPerAmount: 1,
        amount: example.$1,
        quantityConfidence: 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('local database read'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: MealIngredientAmountSheet(
                draft: draft,
                portions: [
                  IngredientPortionData(
                    portionId: 1,
                    name: 'Roll',
                    unitHint: 'ml',
                    gramsPerPortion: example.$2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Roll'));
      await tester.pumpAndSettle();
      final expected = example.$1 / example.$2;
      expect(
        tester
            .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
            .value,
        expected,
      );
      final shown = expected.toString().replaceAll('.', ',');
      expect(find.textContaining(shown), findsOneWidget);
      expect(find.textContaining('= ${example.$2.toInt()} g'), findsOneWidget);
      await tester.tap(find.textContaining(shown));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(
        find.byType(TextFormField).last,
      );
      expect(field.controller!.text.replaceAll(',', '.'), expected.toString());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'English portion value and editing use the same decimal separator',
    (tester) async {
      const draft = MealIngredientsDraft(
        ingredient: IngredientDraft.existing(
          id: 1,
          name: 'Bread',
          carbsPer100g: 40,
          fatPer100g: 2,
          fiberPer100g: 3,
          proteinPer100g: 8,
          nutritionConfidence: 1,
          isReference: false,
        ),
        ingredientPortion: IngredientPortionDraft(
          portion: PortionSelection.empty(),
          amount: 1,
        ),
        recordedGramsPerAmount: 1,
        amount: 100,
        quantityConfidence: 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('local database read'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MealIngredientAmountSheet(
                draft: draft,
                portions: [
                  IngredientPortionData(
                    portionId: 1,
                    name: 'Roll',
                    unitHint: 'g',
                    gramsPerPortion: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Roll'));
      await tester.pumpAndSettle();
      final expected = (100 / 30).toString();
      expect(find.textContaining(expected), findsOneWidget);
      await tester.tap(find.textContaining(expected));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        expected,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown old portion weight cannot be converted or saved', (
    tester,
  ) async {
    const draft = MealIngredientsDraft(
      ingredient: IngredientDraft.existing(
        id: 1,
        name: 'Bread',
        carbsPer100g: 40,
        fatPer100g: 2,
        fiberPer100g: 3,
        proteinPer100g: 8,
        nutritionConfidence: 1,
        isReference: false,
      ),
      ingredientPortion: IngredientPortionDraft(
        portion: PortionSelection.existing(id: 1, name: 'Slice', unitHint: 'g'),
        amount: 0,
      ),
      amount: 2,
      quantityConfidence: 1,
      entryType: 'planned',
      consumedAmount: null,
      consumedConfidence: null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith(
            (_) => throw StateError('local database read'),
          ),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: MealIngredientAmountSheet(
              draft: draft,
              portions: [
                IngredientPortionData(
                  portionId: 2,
                  name: 'Roll',
                  unitHint: 'g',
                  gramsPerPortion: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final choices = tester.widget<MealIngredientPortionChoices>(
      find.byType(MealIngredientPortionChoices),
    );
    choices.onSelected(choices.portions.single);
    await tester.pumpAndSettle();
    final after = tester.widget<MealIngredientPortionChoices>(
      find.byType(MealIngredientPortionChoices),
    );
    expect(
      after.draft.ingredientPortion.portion,
      draft.ingredientPortion.portion,
    );
    expect(
      tester
          .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
          .value,
      2,
    );
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(MealIngredientAmountSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
