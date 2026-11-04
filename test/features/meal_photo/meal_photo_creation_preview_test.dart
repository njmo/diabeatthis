import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_draft_ingredient_resolver.dart';
import 'package:diabeatthis/features/meal_photo/data/drift_meal_photo_local_ingredient_reader.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_ingredient_creation_check.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_item.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_creation_preview_scope.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_selection_origin.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;
import 'meal_photo_reference_prefill_test.dart' show harness;

void main() {
  test('reference preview and save use the same reuse rule', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftSelectedCatalogIngredientStore(db);
    final check = MealPhotoIngredientCreationCheck(db, store);
    final item = MealPhotoReviewItem.fromProposal(
      const MealPhotoProposalParser().parse(fixtures.proposal()).reference,
    ).acceptReference();
    expect(await check(item), isTrue);
    await DriftMealPhotoDraftIngredientResolver(
      db: db,
      local: DriftMealPhotoLocalIngredientReader(db),
      catalogStore: store,
    ).resolve(item);
    expect(await check(item), isFalse);
    expect(
      await check(item.withManualReference(item.referenceNutrition!.scaled(2))),
      isTrue,
    );
    expect(await check(item.assign(fixtures.candidate)), isFalse);
  });

  for (final newRecord in [true, false]) {
    testWidgets('new chip follows persistence preview $newRecord', (
      tester,
    ) async {
      final item = MealPhotoReviewItem.fromProposal(
        const MealPhotoProposalParser().parse(fixtures.proposal()).reference,
      ).acceptReference();
      await tester.pumpWidget(
        harness(
          MealPhotoCreationPreviewScope(
            check: (_) async => newRecord,
            child: MealPhotoSelectionOrigin(item: item),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New'), newRecord ? findsOneWidget : findsNothing);
    });
  }
}
