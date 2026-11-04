import 'catalog_ingredient.dart';
import 'catalog_search_page.dart';
import 'ingredient_identity.dart';

abstract interface class IngredientCatalogRepository {
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  });
  Future<CatalogIngredient> get(
    IngredientIdentity identity, {
    String languageCode = 'en',
  });
}
