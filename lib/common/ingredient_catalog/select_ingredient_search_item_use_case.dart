import 'ingredient_catalog_repository.dart';
import 'ingredient_identity.dart';
import 'ingredient_search_item.dart';
import 'selected_catalog_ingredient_store.dart';

class SelectIngredientSearchItemUseCase {
  const SelectIngredientSearchItemUseCase({
    required this.catalog,
    required this.store,
  });
  final IngredientCatalogRepository catalog;
  final SelectedCatalogIngredientStore store;
  Future<int> call(
    IngredientSearchItem item, {
    required String languageCode,
  }) async {
    final existing = await store.findLocalId(item.identity);
    if (item.localIngredientId != null) {
      if (existing != item.localIngredientId) {
        throw StateError('Selected ingredient identity is stale');
      }
      return existing!;
    }
    if (existing != null) return existing;
    if (item.identity.source == IngredientSource.local) {
      throw StateError('Selected local ingredient is missing');
    }
    final ingredient = await catalog.get(
      item.identity,
      languageCode: languageCode,
    );
    return store.mirror(ingredient);
  }
}
