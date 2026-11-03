import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/load_ingredient_details_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/scripted_ingredient_details_database.dart';
import '../../helpers/regression/scripted_ingredient_details_ingredient_dao.dart';
import '../../helpers/regression/scripted_ingredient_details_meal_dao.dart';
import '../../helpers/regression/scripted_ingredient_details_portion_dao.dart';
import '../../helpers/regression/scripted_read.dart';

void main() {
  final at = DateTime.utc(2026, 9, 1, 12);
  final stamp = at.millisecondsSinceEpoch;
  for (final mode in ['eu', 'non_eu']) {
    for (final reference in [false, true]) {
      test(
        'details preserve current facts, old facts and portion identity: $mode reference=$reference',
        () async {
          final ingredients = ScriptedRead<IngredientData>('ingredient', [
            (
              arguments: [17],
              respond: () => IngredientData(
                id: 17,
                name: 'Bread',
                carbsPer100g: 50,
                fiberPer100g: 8,
                fatPer100g: 4,
                proteinPer100g: 10,
                carbsLabelMode: mode,
                nutritionConfidence: .9,
                isReference: reference ? 1 : 0,
                createdAt: stamp,
                updatedAt: stamp,
                isSynced: false,
                brand: 'Example',
                barcode: '123',
                iconAssetPath: 'assets/bread.svg',
                kcalPer100g: 276,
                netKcalPer100g: 244,
                wbtKcalPer100g: 76,
                ig: 50,
              ),
            ),
          ]);
          final portions = ScriptedRead<List<PortionData>>('portions', [
            (
              arguments: [17],
              respond: () => [
                const PortionData(
                  id: 4,
                  name: 'Slice',
                  unitHint: 'piece',
                  isSynced: false,
                ),
                const PortionData(
                  id: 5,
                  name: 'Missing conversion',
                  unitHint: 'piece',
                  isSynced: false,
                ),
              ],
            ),
          ]);
          final grams = ScriptedRead<double?>('portion grams', [
            (arguments: [17, 4], respond: () => 30),
            (arguments: [17, 5], respond: () => null),
          ]);
          final meals = ScriptedRead<List<MealData>>('usage', [
            (arguments: [17], respond: () => []),
          ]);
          final history = ScriptedRead<List<IngredientStatusHistoryData>>(
            'history',
            [
              (
                arguments: [17],
                respond: () => [
                  IngredientStatusHistoryData(
                    id: 8,
                    ingredientId: 17,
                    carbsPer100g: 40,
                    fiberPer100g: 6,
                    fatPer100g: 3,
                    proteinPer100g: 9,
                    nutritionConfidence: .4,
                    createdAt: stamp - 1000,
                  ),
                ],
              ),
            ],
          );
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(
                ScriptedIngredientDetailsDatabase(
                  ScriptedIngredientDetailsIngredientDao(ingredients, history),
                  ScriptedIngredientDetailsPortionDao(portions, grams),
                  ScriptedIngredientDetailsMealDao(meals),
                ),
              ),
            ],
          );
          addTearDown(container.dispose);
          final result = await container.read(
            loadIngredientDetailsUseCaseProvider,
          )(17);
          expect(result.ingredient.id, 17);
          expect(
            result.ingredient.carbsLabelMode,
            mode == 'eu' ? CarbsLabelMode.eu : CarbsLabelMode.nonEu,
          );
          expect(result.ingredient.carbsPer100g, 50);
          expect(result.ingredient.fiberPer100g, 8);
          expect(result.ingredient.fatPer100g, 4);
          expect(result.ingredient.proteinPer100g, 10);
          expect(result.ingredient.nutritionConfidence, .9);
          expect(result.ingredient.isReference, reference);
          expect(result.ingredient.brand, 'Example');
          expect(result.ingredient.barcode, '123');
          expect(result.ingredient.iconAssetPath, 'assets/bread.svg');
          expect(result.ingredient.kcalPer100g, 276);
          expect(result.ingredient.netKcalPer100g, 244);
          expect(result.ingredient.wbtKcalPer100g, 76);
          expect(result.ingredient.ig, 50);
          expect(result.portions.map((p) => p.portionId), [4, 5]);
          expect(result.portions.map((p) => p.gramsPerPortion), [30, 0]);
          expect(result.history.single.carbsPer100g, 40);
          expect(result.history.single.nutritionConfidence, .4);
          expect(
            result.history.single.createdAt.millisecondsSinceEpoch,
            stamp - 1000,
          );
          expect(result.usages, isEmpty);
          ingredients.verifyComplete();
          portions.verifyComplete();
          grams.verifyComplete();
          meals.verifyComplete();
          history.verifyComplete();
        },
      );
    }
  }
  for (final failingRead in [
    'ingredient',
    'portions',
    'usage',
    'history',
    'grams',
  ]) {
    test(
      'details surface $failingRead failure without substituting empty facts',
      () async {
        final error = StateError('Unavailable $failingRead');
        final stages = ['ingredient', 'portions', 'usage', 'history', 'grams'];
        bool reached(String stage) =>
            stages.indexOf(stage) <= stages.indexOf(failingRead);
        T result<T>(String stage, T value) {
          if (failingRead == stage) throw error;
          return value;
        }

        final ingredient = ScriptedRead<IngredientData>('ingredient', [
          (
            arguments: [17],
            respond: () => result(
              'ingredient',
              IngredientData(
                id: 17,
                name: 'Bread',
                carbsPer100g: 50,
                fatPer100g: 4,
                fiberPer100g: 8,
                proteinPer100g: 10,
                carbsLabelMode: 'eu',
                nutritionConfidence: .9,
                isReference: 0,
                createdAt: stamp,
                updatedAt: stamp,
                isSynced: false,
              ),
            ),
          ),
        ]);
        final portions = ScriptedRead<List<PortionData>>(
          'portions',
          reached('portions')
              ? [
                  (
                    arguments: [17],
                    respond: () => result('portions', [
                      const PortionData(
                        id: 4,
                        name: 'Slice',
                        unitHint: 'piece',
                        isSynced: false,
                      ),
                    ]),
                  ),
                ]
              : [],
        );
        final usage = ScriptedRead<List<MealData>>(
          'usage',
          reached('usage')
              ? [
                  (
                    arguments: [17],
                    respond: () => result('usage', <MealData>[]),
                  ),
                ]
              : [],
        );
        final history = ScriptedRead<List<IngredientStatusHistoryData>>(
          'history',
          reached('history')
              ? [
                  (
                    arguments: [17],
                    respond: () =>
                        result('history', <IngredientStatusHistoryData>[]),
                  ),
                ]
              : [],
        );
        final grams = ScriptedRead<double?>(
          'grams',
          reached('grams')
              ? [
                  (arguments: [17, 4], respond: () => result('grams', 30.0)),
                ]
              : [],
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(
              ScriptedIngredientDetailsDatabase(
                ScriptedIngredientDetailsIngredientDao(ingredient, history),
                ScriptedIngredientDetailsPortionDao(portions, grams),
                ScriptedIngredientDetailsMealDao(usage),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await expectLater(
          container.read(loadIngredientDetailsUseCaseProvider)(17),
          throwsA(same(error)),
        );
        ingredient.verifyComplete();
        portions.verifyComplete();
        usage.verifyComplete();
        history.verifyComplete();
        grams.verifyComplete();
      },
    );
  }
}
