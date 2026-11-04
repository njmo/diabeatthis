import 'ingredient_search_item.dart';

class CatalogSearchPage {
  CatalogSearchPage({
    required List<IngredientSearchItem> items,
    required this.releaseId,
    this.nextCursor,
  }) : items = List.unmodifiable(items);
  final List<IngredientSearchItem> items;
  final String releaseId;
  final String? nextCursor;
}
