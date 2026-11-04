import 'catalog_ingredient.dart';
import 'ingredient_identity.dart';

/// Stores selected facts only, never a synchronized copy of the whole catalog.
abstract interface class SelectedCatalogIngredientStore {
  Future<int?> findLocalId(IngredientIdentity identity);

  /// Implementations atomically deduplicate identity. Existing meal facts must
  /// not be rewritten implicitly when a newer catalog revision is available.
  Future<int> mirror(CatalogIngredient ingredient);
}
