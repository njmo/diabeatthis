import 'dart:convert';

import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft_validation.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/validate_meal_photo_review_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'US fiber may equal total carbs while EU carbs and fiber are independent',
    () {
      const ingredient = IngredientDraft.draft(
        name: 'Fiber and protein',
        carbsPer100g: 10,
        fiberPer100g: 10,
        proteinPer100g: 30,
        fatPer100g: 5,
        nutritionConfidence: .5,
        isReference: false,
        carbsLabelMode: CarbsLabelMode.nonEu,
      );
      expect(ingredient.validateMacroRanges, returnsNormally);
      expect(
        ingredient.copyWith(fiberPer100g: 11).validateMacroRanges,
        throwsArgumentError,
      );
      expect(
        ingredient
            .copyWith(carbsLabelMode: CarbsLabelMode.eu, fiberPer100g: 20)
            .validateMacroRanges,
        returnsNormally,
      );
    },
  );

  for (final fat in [11.1, 11.2]) {
    test(
      'photo and meal draft agree on the raw WBT threshold for $fat g fat',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final raw = jsonDecode(fixtures.proposal()) as Map<String, dynamic>;
        (raw['reference'] as Map<String, dynamic>)['reference_nutrition'] = {
          'carbs': 0,
          'fiber': 0,
          'fat': fat,
          'protein': 0,
          'carbs_label_mode': 'eu',
        };
        final source = const MealPhotoProposalParser().parse(jsonEncode(raw));
        final item = MealPhotoReviewItem.fromProposal(source.reference)
            .acceptReference()
            .adjust(
              grams: 100,
              quantityConfidence: .5,
              nutritionConfidence: .5,
              reviewed: true,
            );
        final review = AcceptedMealPhotoReview(
          name: source.name,
          mode: MealPhotoMode.reference,
          items: [item],
          proposalResponse: source.rawResponse,
          sourceProposal: source,
        );
        final provider = Provider(
          (ref) => calculateMealIngredientsMacronutrients(ref, [
            MealIngredientsDraft(
              ingredient: IngredientDraft.draft(
                name: 'Fat',
                carbsPer100g: 0,
                fiberPer100g: 0,
                fatPer100g: fat,
                proteinPer100g: 0,
                nutritionConfidence: .5,
                isReference: false,
              ),
              ingredientPortion: const IngredientPortionDraft(
                portion: PortionSelection.empty(),
                amount: 1,
              ),
              amount: 100,
              quantityConfidence: .5,
              entryType: 'planned',
              consumedAmount: null,
              consumedConfidence: null,
            ),
          ]),
        );
        final macros = await container.read(provider);
        if (fat == 11.1) {
          expect(
            () => const ValidateMealPhotoReviewUseCase()(review),
            throwsStateError,
          );
          expect(macros.extendedCarbsTotal, 0);
        } else {
          expect(
            () => const ValidateMealPhotoReviewUseCase()(review),
            returnsNormally,
          );
          expect(macros.extendedCarbsTotal, 11);
        }
      },
    );
  }
}
