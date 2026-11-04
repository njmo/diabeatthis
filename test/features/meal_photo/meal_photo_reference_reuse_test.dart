import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_draft_ingredient_resolver.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_local_ingredient_reader.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test(
    'identical photo reference reuses its record and keeps meal confidence',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final resolver = DriftMealPhotoDraftIngredientResolver(
        db: db,
        local: DriftMealPhotoLocalIngredientReader(db),
        catalogStore: DriftSelectedCatalogIngredientStore(db),
      );
      final item =
          MealPhotoReviewItem.fromProposal(
            const MealPhotoProposalParser()
                .parse(fixtures.proposal())
                .reference,
          ).acceptReference().adjust(
            grams: 150,
            quantityConfidence: .5,
            nutritionConfidence: .75,
            reviewed: true,
          );
      final first = await resolver.resolve(item);
      final second = await resolver.resolve(
        item.adjust(
          grams: 150,
          quantityConfidence: .5,
          nutritionConfidence: .95,
          reviewed: true,
        ),
      );
      expect(second.getIngredientIdOrNull(), first.getIngredientIdOrNull());
      expect(second.nutritionConfidence, .95);
      expect(
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM ingredient')
                .getSingle())
            .read<int>('n'),
        1,
      );
      final different = await resolver.resolve(
        item.withManualReference(
          item.referenceNutrition!.scaled(2),
          confidence: .75,
        ),
      );
      expect(
        different.getIngredientIdOrNull(),
        isNot(first.getIngredientIdOrNull()),
      );
    },
  );
}
