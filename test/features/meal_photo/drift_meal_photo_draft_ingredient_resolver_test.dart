import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_draft_ingredient_resolver.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_local_ingredient_reader.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_draft_settings.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_draft_writer.dart';
import 'package:diabeatthis/features/meal_photo/data/prepared_meal_photo_saver.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_nutrition.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

class FailingPhotoDraftWriter implements MealPhotoDraftWriter {
  @override
  Future<int> write(MealDraft draft) async =>
      throw StateError('Simulated database write failure');
}

void main() {
  test(
    'failed meal write rolls back normalized reference and its explicit origin together',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final resolver = DriftMealPhotoDraftIngredientResolver(
        db: db,
        local: DriftMealPhotoLocalIngredientReader(db),
        catalogStore: DriftSelectedCatalogIngredientStore(db),
      );
      final proposal = const MealPhotoProposalParser().parse(
        fixtures.proposal(),
      );
      final item = MealPhotoReviewItem.fromProposal(proposal.reference)
          .acceptReference()
          .adjust(
            grams: 250,
            quantityConfidence: .7,
            nutritionConfidence: .6,
            reviewed: true,
          );
      final review = AcceptedMealPhotoReview(
        name: 'Lunch',
        mode: MealPhotoMode.reference,
        items: [item],
        proposalResponse: proposal.rawResponse,
        sourceProposal: proposal,
      );
      final saver = PreparedMealPhotoSaver(
        ingredients: resolver,
        writer: FailingPhotoDraftWriter(),
        settings: () => MealPhotoDraftSettings(
          category: MealCategory.lunch,
          plannedAt: DateTime(2026),
        ),
        runAtomic: (action) => db.transaction(action),
      );
      await expectLater(saver.save(review), throwsStateError);
      expect(
        (await db
                .customSelect('SELECT COUNT(*) AS count FROM ingredient')
                .getSingle())
            .read<int>('count'),
        0,
      );
      expect(
        (await db
                .customSelect('SELECT COUNT(*) AS count FROM ingredient_origin')
                .getSingle())
            .read<int>('count'),
        0,
      );
    },
  );
  test(
    'frozen mirrored candidate uses reviewed local row and validates external identity and revision',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      const identity = IngredientIdentity(
        source: IngredientSource.firebase,
        sourceId: 'usda_123',
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
      final id = await store.mirror(facts);
      final resolver = DriftMealPhotoDraftIngredientResolver(
        db: db,
        local: DriftMealPhotoLocalIngredientReader(db),
        catalogStore: store,
      );
      final proposal = const MealPhotoProposalParser()
          .parse(fixtures.proposal())
          .itemized
          .single;
      MealPhotoReviewItem selected(String revision) =>
          MealPhotoReviewItem.fromProposal(proposal).assign(
            MealPhotoCandidate(
              identity: identity,
              name: 'Potatoes',
              localIngredientId: id,
              catalogRevision: revision,
              nutritionPer100g: const MealPhotoNutrition(
                carbs: 20,
                fiber: 2,
                fat: 0,
                protein: 2,
                carbsLabelMode: CarbsLabelMode.eu,
              ),
            ),
          );
      expect(
        (await resolver.resolve(selected('r1'))).getIngredientIdOrNull(),
        id,
      );
      await expectLater(resolver.resolve(selected('r2')), throwsStateError);
      expect(
        (await db
                .customSelect('SELECT COUNT(*) AS count FROM ingredient')
                .getSingle())
            .read<int>('count'),
        1,
      );
    },
  );
}
