import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/persistence/insert_ingredient_draft.dart';
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
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_details_data_mapper.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/ingredient_catalog/catalog_persistence_test.dart'
    show catalogItem;
import 'meal_photo_proposal_test.dart' as fixtures;

class ConfidenceRegressionWriter implements MealPhotoDraftWriter {
  const ConfidenceRegressionWriter(this.useCase);
  final AddMealUseCase useCase;
  @override
  Future<int> write(MealDraft draft) async =>
      (await useCase.call(draft, suggestMissingIcons: false)).id;
}

void main() {
  for (final kind in ['local', 'catalog', 'reused_reference']) {
    test(
      '$kind preserves per-meal confidence through reload snapshots and backup',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final store = DriftSelectedCatalogIngredientStore(db);
        final resolver = DriftMealPhotoDraftIngredientResolver(
          db: db,
          local: DriftMealPhotoLocalIngredientReader(db),
          catalogStore: store,
        );
        final source = const MealPhotoProposalParser().parse(
          fixtures.proposal(),
        );
        var item = MealPhotoReviewItem.fromProposal(
          kind == 'reused_reference'
              ? source.reference
              : source.itemized.single,
        );
        final int ingredientId;
        if (kind == 'reused_reference') {
          final initial = item.acceptReference();
          final draft = await resolver.resolve(initial);
          ingredientId = draft.getIngredientIdOrNull()!;
          item = initial;
        } else {
          final facts = catalogItem();
          ingredientId = kind == 'local'
              ? (await insertIngredientDraft(
                  db,
                  IngredientDraft.draft(
                    name: facts.name,
                    carbsPer100g: facts.carbsPer100g,
                    fiberPer100g: facts.fiberPer100g,
                    fatPer100g: facts.fatPer100g,
                    proteinPer100g: facts.proteinPer100g,
                    nutritionConfidence: .25,
                    isReference: false,
                    carbsLabelMode: facts.carbsLabelMode,
                  ),
                )).id
              : await store.mirror(facts);
          item = item.assign(
            MealPhotoCandidate(
              identity: kind == 'local'
                  ? IngredientIdentity(
                      source: IngredientSource.local,
                      sourceId: '$ingredientId',
                    )
                  : facts.identity,
              name: facts.name,
              localIngredientId: kind == 'local' ? ingredientId : null,
              catalogRevision: kind == 'catalog' ? facts.revision : null,
              catalogIngredient: kind == 'catalog' ? facts : null,
              nutritionConfidence: kind == 'local' ? .25 : 0,
              nutritionConfidenceAssessed: false,
              nutritionPer100g: MealPhotoNutrition(
                carbs: facts.carbsPer100g,
                fiber: facts.fiberPer100g,
                fat: facts.fatPer100g,
                protein: facts.proteinPer100g,
                carbsLabelMode: facts.carbsLabelMode,
              ),
            ),
          );
        }
        final originalConfidence = (await db.ingredientDao.getIngredientById(
          ingredientId,
        )).nutritionConfidence;
        final saver = PreparedMealPhotoSaver(
          ingredients: resolver,
          writer: ConfidenceRegressionWriter(
            container.read(addMealUseCaseProvider),
          ),
          settings: () => MealPhotoDraftSettings(
            category: MealCategory.lunch,
            plannedAt: DateTime(2026, 11, 4, 12),
          ),
          runAtomic: (action) => db.transaction(action),
        );
        for (final confidence in [.75, 0.0]) {
          final reviewed = item.adjust(
            grams: 150,
            quantityConfidence: .5,
            nutritionConfidence: confidence,
            reviewed: true,
          );
          final mealId = await saver.save(
            AcceptedMealPhotoReview(
              name: 'Reviewed meal $confidence',
              mode: kind == 'reused_reference'
                  ? MealPhotoMode.reference
                  : MealPhotoMode.itemized,
              items: [reviewed],
              proposalResponse: source.rawResponse,
              sourceProposal: source,
            ),
          );
          final row = (await db.mealIngredientsDao.getMealIngredientsForMeal(
            mealId,
          )).single;
          expect(row.nutritionConfidenceOverride, confidence);
          final reloaded = await container.read(
            getMealIngredientsDraftForMealProvider(mealId).future,
          );
          expect(reloaded.single.nutritionConfidenceOverride, confidence);
          final snapshots = container.read(mealSnapshotControllerProvider);
          await snapshots.createPlannedSnapshot(mealId);
          var snapshot = (await db.select(db.mealSnapshot).get()).last;
          expect(snapshot.carbWeightedNutritionConfidence, confidence);
          final meal = await db.mealDao.getMealById(mealId);
          final details = await MealDetailsDataMapper(db: db).mapIngredient(
            meal: meal!,
            mealIngredient: row,
            plannedSnapshot: snapshot,
            consumedSnapshot: null,
          );
          expect(details.plannedNutrition.nutritionConfidence, confidence);
          await db.mealIngredientsDao.updateMealIngredientConsumed(
            row.id,
            150,
            .5,
          );
          container.invalidate(getMealIngredientsDraftForMealProvider(mealId));
          await snapshots.saveConsumedSnapshot(mealId);
          snapshot = (await db.select(db.mealSnapshot).get()).last;
          expect(snapshot.carbWeightedNutritionConfidence, confidence);
        }
        expect(
          (await db.ingredientDao.getIngredientById(
            ingredientId,
          )).nutritionConfidence,
          originalConfidence,
        );
        final backup = await DatabaseBackupService(
          db,
        ).exportToJson(DatabaseBackupScope.full);
        final restored = DatabaseImpl(NativeDatabase.memory());
        addTearDown(restored.close);
        await DatabaseBackupService(restored).importFromJson(backup);
        expect(
          (await restored.select(restored.mealIngredients).get()).map(
            (row) => row.nutritionConfidenceOverride,
          ),
          [.75, 0.0],
        );
      },
    );
  }
}
