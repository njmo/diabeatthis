import 'package:drift/drift.dart';

import '../../../common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import '../../../common/ingredient_catalog/ingredient_identity.dart';
import '../../../core/drift/database_impl.dart';
import '../../ingredients/data/drafts/ingredient_draft.dart';
import '../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../ingredients/data/persistence/insert_ingredient_draft.dart';
import '../domain/models/meal_photo_item.dart';
import '../domain/models/meal_photo_review_item.dart';
import 'find_existing_photo_reference_id.dart';
import 'meal_photo_draft_ingredient_resolver.dart';
import 'meal_photo_local_ingredient_reader.dart';
import 'meal_photo_reference_draft_factory.dart';

/// Called inside the meal save transaction, including provenance and mirroring.
class DriftMealPhotoDraftIngredientResolver
    implements MealPhotoDraftIngredientResolver {
  const DriftMealPhotoDraftIngredientResolver({
    required this.db,
    required this.local,
    required this.catalogStore,
  });
  final DatabaseImpl db;
  final MealPhotoLocalIngredientReader local;
  final DriftSelectedCatalogIngredientStore catalogStore;
  @override
  Future<IngredientDraft> resolve(MealPhotoReviewItem item) async {
    if (item.product case final product?) {
      final int id;
      if (product.identity.source == IngredientSource.local ||
          product.localIngredientId != null) {
        id = product.localIngredientId ?? int.parse(product.identity.sourceId);
      } else {
        final snapshot = product.catalogIngredient;
        if (snapshot == null ||
            snapshot.identity != product.identity ||
            snapshot.revision != product.catalogRevision) {
          throw StateError('Missing reviewed catalog snapshot');
        }
        id = await catalogStore.mirror(snapshot);
      }
      if (product.identity.source == IngredientSource.local &&
          product.identity.sourceId != id.toString()) {
        throw StateError('Local ingredient identity mismatch');
      }
      if (product.identity.source == IngredientSource.firebase) {
        if (await catalogStore.findLocalId(product.identity) != id) {
          throw StateError('Catalog mirror identity mismatch');
        }
        final origin = await db
            .customSelect(
              'SELECT source_revision FROM ingredient_origin WHERE ingredient_id = ?',
              variables: [Variable(id)],
            )
            .getSingle();
        if (product.catalogRevision == null ||
            origin.readNullable<String>('source_revision') !=
                product.catalogRevision) {
          throw StateError(
            'Catalog revision changed; review the product again',
          );
        }
      }
      final current = await local.get(id);
      final expected = product.nutritionPer100g;
      if (current.carbsPer100g != expected.carbs ||
          current.fiberPer100g != expected.fiber ||
          current.fatPer100g != expected.fat ||
          current.proteinPer100g != expected.protein ||
          current.carbsLabelMode != expected.carbsLabelMode ||
          current.isReference ||
          current.nutritionConfidence != (product.nutritionConfidence ?? 0)) {
        throw StateError(
          'Ingredient facts changed; review the selected product again',
        );
      }
      return current.toDraft().copyWith(
        nutritionConfidence: item.nutritionConfidence,
      );
    }
    if (!item.referenceAccepted || !item.validWeight) {
      throw StateError('Reference requires physical weight and acceptance');
    }
    final draft = const MealPhotoReferenceDraftFactory()(item);
    final existingId = await findExistingPhotoReferenceId(db, item);
    if (existingId != null) {
      return (await local.get(
        existingId,
      )).toDraft().copyWith(nutritionConfidence: item.nutritionConfidence);
    }
    final total = item.referenceNutrition!;
    final saved = await insertIngredientDraft(db, draft);
    await catalogStore.recordPhotoReferenceOrigin(
      saved.id,
      nutritionConfidenceAssessed: item.reviewed,
      referenceScope:
          item.proposal.referenceScope == MealPhotoReferenceScope.wholeMeal
          ? 'whole_plate'
          : 'component',
      provenance: {
        'schemaVersion': 1,
        'componentId': item.proposal.id,
        'estimatedName': item.proposal.name,
        'confirmedWeightGrams': item.weightGrams,
        'recognitionConfidence': item.proposal.recognitionConfidence,
        'quantityConfidence': item.quantityConfidence,
        'nutritionConfidence': item.nutritionConfidence,
        'totalNutrition': {
          'carbs': total.carbs,
          'fiber': total.fiber,
          'fat': total.fat,
          'protein': total.protein,
          'carbsLabelMode': total.carbsLabelMode.name,
        },
      },
    );
    return saved.toDraft();
  }
}
