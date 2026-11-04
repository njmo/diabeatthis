import 'catalog_search_page.dart';
import 'ingredient_catalog_repository.dart';
import 'ingredient_match_score.dart';
import 'ingredient_search_item.dart';
import 'local_ingredient_search_repository.dart';

class UnifiedIngredientSearchUseCase {
  const UnifiedIngredientSearchUseCase({
    required this.local,
    required this.catalog,
  });
  final LocalIngredientSearchRepository local;
  final IngredientCatalogRepository catalog;
  Future<List<IngredientSearchItem>> searchLocal(String query) =>
      local.search(query);
  Future<CatalogSearchPage> searchCatalog(
    String query,
    String languageCode, {
    String? cursor,
  }) async {
    final normalized = ingredientCatalogQuery(query);
    final page = await catalog.search(
      query: normalized,
      languageCode: languageCode,
      cursor: cursor,
    );
    if (cursor != null ||
        page.items.isNotEmpty ||
        normalized.split(' ').length < 2) {
      return page;
    }
    final tokens = normalized.split(' ');
    const preparation = {
      'cooked',
      'boiled',
      'raw',
      'roasted',
      'fried',
      'grilled',
      'baked',
      'steamed',
    };
    final food = tokens.where((token) => !preparation.contains(token)).toList();
    if (food.isEmpty) return page;
    final broader = await catalog.search(
      query: food.first,
      languageCode: languageCode,
    );
    final ranked =
        broader.items
            .where(
              (item) =>
                  ingredientNameMatchScore(
                    query,
                    item.name,
                    item.englishName,
                  ) >=
                  .5,
            )
            .toList()
          ..sort(
            (a, b) => ingredientNameMatchScore(
              query,
              b.name,
              b.englishName,
            ).compareTo(ingredientNameMatchScore(query, a.name, a.englishName)),
          );
    return CatalogSearchPage(items: ranked, releaseId: broader.releaseId);
  }

  static List<IngredientSearchItem> merge(
    List<IngredientSearchItem> local,
    List<IngredientSearchItem> remote,
  ) {
    final seen = <String>{};
    return List.unmodifiable(
      [...local, ...remote].where((item) => seen.add(item.identity.stableKey)),
    );
  }
}
