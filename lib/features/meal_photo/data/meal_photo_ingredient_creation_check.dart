import '../../../common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import '../../../common/ingredient_catalog/ingredient_identity.dart';
import '../../../core/drift/database_impl.dart';
import '../domain/models/meal_photo_review_item.dart';
import 'find_existing_photo_reference_id.dart';

class MealPhotoIngredientCreationCheck {
  const MealPhotoIngredientCreationCheck(this.db, this.catalogStore);
  final DatabaseImpl db;
  final DriftSelectedCatalogIngredientStore catalogStore;

  Future<bool?> call(MealPhotoReviewItem item) async {
    if (item.product case final product?) {
      if (product.identity.source == IngredientSource.local ||
          product.localIngredientId != null) {
        return false;
      }
      return await catalogStore.findLocalId(product.identity) == null;
    }
    if (!item.validWeight || item.referenceNutrition == null) return null;
    return await findExistingPhotoReferenceId(db, item) == null;
  }
}
