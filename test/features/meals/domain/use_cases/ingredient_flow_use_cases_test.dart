import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/meals/domain/use_cases/calculate_ingredient_review_use_case.dart';
import 'package:diabeatthis/features/meals/domain/use_cases/ingredient_portions_use_case.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ingredient = IngredientDraft.existing(
    id: 1,
    name: 'Yogurt',
    carbsPer100g: 12,
    fatPer100g: 3,
    fiberPer100g: 2,
    proteinPer100g: 4,
    nutritionConfidence: 0.75,
    isReference: false,
  );
  const piece = PortionSelection.existing(id: 7, name: 'piece', unitHint: 'g');
  final portions = IngredientPortionsUseCase(
    loadCatalog: () async => [piece],
    loadAssigned: (_) async => [piece],
    loadWeight: (_, _) async => 150,
  );

  test(
    'Polish suggestion reuses the standard global portion without inventing a weight',
    () async {
      final selection = await portions.fromSuggestion(
        const RecognizedPortion(
          name: 'sztuka',
          unitHint: 'g',
          grams: 125,
          source: 'nutrition_label',
        ),
      );
      expect(selection, piece);
      final resolved = await portions.resolve(ingredient, selection);
      expect(resolved.selection, piece);
      expect(resolved.grams, 150);
      expect(resolved.exists, isTrue);
    },
  );

  test('a different weight unit keeps a new portion separate', () async {
    const requested = PortionSelection.draft(name: 'sztuka', unitHint: 'kg');
    final result = await portions.resolve(ingredient, requested);
    expect(result.selection, requested);
    expect(result.exists, isFalse);
    expect(result.grams, isNull);
  });

  test(
    'initial selection uses an assigned portion and falls back to grams when none exist',
    () async {
      expect(await portions.initialSelection(ingredient), piece);
      final empty = IngredientPortionsUseCase(
        loadCatalog: () async => [],
        loadAssigned: (_) async => [],
        loadWeight: (_, _) async => null,
      );
      expect(
        await empty.initialSelection(ingredient),
        const PortionSelection.empty(),
      );
    },
  );

  test(
    'review preserves label mode, fractional macros and full amount energy',
    () {
      final eu = const CalculateIngredientReviewUseCase()(ingredient, 150);
      final nonEu = const CalculateIngredientReviewUseCase()(
        ingredient.copyWith(carbsLabelMode: CarbsLabelMode.nonEu),
        150,
      );
      expect(eu.carbs, 18);
      expect(nonEu.carbs, 15);
      expect(eu.protein, 6);
      expect(eu.fat, 4.5);
      expect(eu.calories, 136.5);
    },
  );
}
