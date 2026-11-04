import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_draft_ingredient_resolver.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_local_ingredient_reader.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_nutrition.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'reviewed confidence reaches meal draft without changing the mirrored catalog record',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      const identity = IngredientIdentity(
        source: IngredientSource.firebase,
        sourceId: 'usda_999991',
      );
      const facts = CatalogIngredient(
        identity: identity,
        name: 'Potatoes',
        englishName: 'Potatoes',
        revision: 'r1',
        carbsPer100g: 20,
        fiberPer100g: 2,
        fatPer100g: 0,
        proteinPer100g: 2,
        carbsLabelMode: CarbsLabelMode.eu,
      );
      final store = DriftSelectedCatalogIngredientStore(db);
      final id = await store.mirror(facts);
      final before = (await db.ingredientDao.getIngredientById(
        id,
      )).nutritionConfidence;
      final item =
          MealPhotoReviewItem.fromProposal(
                const MealPhotoProposalParser()
                    .parse(fixtures.proposal())
                    .itemized
                    .single,
              )
              .assign(
                const MealPhotoCandidate(
                  identity: identity,
                  name: 'Potatoes',
                  catalogRevision: 'r1',
                  catalogIngredient: facts,
                  nutritionConfidenceAssessed: false,
                  nutritionPer100g: MealPhotoNutrition(
                    carbs: 20,
                    fiber: 2,
                    fat: 0,
                    protein: 2,
                    carbsLabelMode: CarbsLabelMode.eu,
                  ),
                ),
              )
              .adjust(
                grams: 150,
                quantityConfidence: .5,
                nutritionConfidence: .75,
                reviewed: true,
              );
      final draft = await DriftMealPhotoDraftIngredientResolver(
        db: db,
        local: DriftMealPhotoLocalIngredientReader(db),
        catalogStore: store,
      ).resolve(item);
      expect(draft.nutritionConfidence, .75);
      expect(
        (await db.ingredientDao.getIngredientById(id)).nutritionConfidence,
        before,
      );
    },
  );
}
