import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_draft_ingredient_resolver.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_local_ingredient_reader.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_barcode_candidate_factory.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_ingredient_creation_check.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  const draft = IngredientDraft.draft(
    name: 'Scanned yogurt',
    brand: 'Brand',
    barcode: '5901234123457',
    carbsPer100g: 5,
    fiberPer100g: 0,
    proteinPer100g: 8,
    fatPer100g: 3,
    nutritionConfidence: .8,
    isReference: false,
  );
  for (final rollback in [false, true]) {
    test(
      'barcode assignment preserves estimated grams and defers creation; rollback=$rollback',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final store = DriftSelectedCatalogIngredientStore(db);
        final resolver = DriftMealPhotoDraftIngredientResolver(
          db: db,
          local: DriftMealPhotoLocalIngredientReader(db),
          catalogStore: store,
        );
        final original = MealPhotoReviewItem.fromProposal(
          const MealPhotoProposalParser().parse(fixtures.proposal()).reference,
        );
        final product = const MealPhotoBarcodeCandidateFactory()(draft);
        final item = original.assign(product);
        expect(item.weightGrams, original.weightGrams);
        expect(item.quantityConfidence, original.quantityConfidence);
        expect(product.identity.source, IngredientSource.barcode);
        expect(await db.select(db.ingredient).get(), isEmpty);
        final check = MealPhotoIngredientCreationCheck(db, store);
        expect(await check(item), isTrue);
        Future<void> save() => db.transaction(() async {
          final first = await resolver.resolve(item);
          final second = await resolver.resolve(item);
          expect(first.getIngredientIdOrNull(), second.getIngredientIdOrNull());
          expect(first.barcode, draft.barcode);
          expect(first.brand, draft.brand);
          if (rollback) throw StateError('rollback');
        });
        if (rollback) {
          await expectLater(save(), throwsStateError);
        } else {
          await save();
        }
        expect((await db.select(db.ingredient).get()).length, rollback ? 0 : 1);
        expect(await check(item), rollback);
      },
    );
  }
}
