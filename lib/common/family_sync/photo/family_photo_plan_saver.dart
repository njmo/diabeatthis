import '../../../features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import '../../../features/meal_photo/domain/models/meal_photo_review_exception.dart';
import '../../../features/meal_photo/domain/ports/meal_photo_meal_saver.dart';
import '../../ingredient_catalog/ingredient_identity.dart';
import '../../meal/meal_category.dart';

/// Sends a plan only. Ingredient creation and meal execution remain on the child.
class FamilyPhotoPlanSaver implements MealPhotoMealSaver {
  const FamilyPhotoPlanSaver({
    required this.submit,
    required this.category,
    required this.plannedAt,
  });
  final Future<void> Function(Map<String, dynamic>) submit;
  final MealCategory? Function() category;
  final DateTime Function() plannedAt;
  @override
  Future<int> save(AcceptedMealPhotoReview review) async {
    final selected = category();
    final time = plannedAt();
    if (selected == null ||
        !time.isAfter(DateTime.now()) ||
        !time.isBefore(DateTime.now().add(const Duration(days: 366)))) {
      throw MealPhotoReviewException(MealPhotoReviewFailure.futureTimeRequired);
    }
    if (review.items.isEmpty || review.items.length > 30) {
      throw MealPhotoReviewException(MealPhotoReviewFailure.invalidMass);
    }
    final byIdentity = <String, Map<String, dynamic>>{};
    for (final item in review.items) {
      final product = item.product;
      if (product == null ||
          !item.validWeight ||
          (product.localIngredientId == null &&
              (product.identity.source != IngredientSource.firebase ||
                  product.catalogRevision == null))) {
        throw MealPhotoReviewException(
          MealPhotoReviewFailure.legacyReferenceUnsupported,
        );
      }
      final key = product.localIngredientId == null
          ? 'catalog:${product.identity.sourceId}'
          : 'local:${product.localIngredientId}';
      final previous = byIdentity[key];
      if (previous != null &&
          previous['catalogRevision'] !=
              (product.localIngredientId == null
                  ? product.catalogRevision
                  : null)) {
        throw StateError('Catalog revision changed');
      }
      final grams =
          item.weightGrams! + ((previous?['grams'] as num?)?.toDouble() ?? 0);
      if (grams > 10000) {
        throw MealPhotoReviewException(MealPhotoReviewFailure.invalidMass);
      }
      byIdentity[key] = {
        'ingredientId': product.localIngredientId,
        'catalogId': product.localIngredientId == null
            ? product.identity.sourceId
            : null,
        'catalogRevision': product.localIngredientId == null
            ? product.catalogRevision
            : null,
        'grams': grams,
      };
    }
    await submit({
      'name': review.name,
      'category': selected.name,
      'plannedAt': time.millisecondsSinceEpoch,
      'notes': '',
      'ingredients': byIdentity.values.toList(),
    });
    // The shared review's completion marker is not a local meal ID.
    return 0;
  }
}
