import 'ingredient_search_item.dart';

abstract interface class LocalIngredientSearchRepository {
  Future<List<IngredientSearchItem>> search(String query, {int limit = 20});
}
