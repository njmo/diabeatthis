import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_search_page.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_origin_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/ingredient_catalog/local_ingredient_search_repository.dart';
import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_catalog_selection_controller.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Retains each existing scenario's ingredient fixtures, adapting only their
/// search/selection boundary to the shared catalog interfaces.
List<Override> catalogSearchInterfaceOverrides() => [
  localIngredientSearchRepositoryProvider.overrideWith(
    (ref) => FixtureIngredientSearchRepository(
      (query) => ref.read(ingredientsByQueryProvider(query).future),
    ),
  ),
  catalogRepositoryProvider.overrideWithValue(EmptyRemoteIngredientCatalog()),
  ingredientCatalogSelectionControllerProvider.overrideWith(
    (ref) => FixtureIngredientSelectionController(
      ref.read(localIngredientSearchRepositoryProvider)
          as FixtureIngredientSearchRepository,
    ),
  ),
];

class FixtureIngredientSearchRepository
    implements LocalIngredientSearchRepository {
  FixtureIngredientSearchRepository(this.load);
  final Future<List<Ingredient>> Function(String query) load;
  final Map<int, Ingredient> ingredients = {};
  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async {
    final rows = await load(query);
    for (final row in rows) {
      ingredients[row.id] = row;
    }
    return rows
        .take(limit)
        .map(
          (row) => IngredientSearchItem(
            identity: IngredientIdentity(
              source: IngredientSource.local,
              sourceId: '${row.id}',
            ),
            name: row.name,
            details: row.brand ?? '',
            localIngredientId: row.id,
            isReference: row.isReference,
            iconAssetPath: row.iconAssetPath,
          ),
        )
        .toList();
  }
}

class FixtureIngredientSelectionController extends Fake
    implements IngredientCatalogSelectionController {
  FixtureIngredientSelectionController(this.search);
  final FixtureIngredientSearchRepository search;
  @override
  Future<IngredientDraft> select(
    IngredientSearchItem item, {
    required String languageCode,
  }) async {
    final ingredient = search.ingredients[item.localIngredientId];
    if (ingredient == null) {
      throw StateError('Selected ingredient was not provided by the scenario');
    }
    return ingredient.toDraft();
  }
}

class EmptyRemoteIngredientCatalog implements IngredientCatalogRepository {
  @override
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  }) async => CatalogSearchPage(items: const [], releaseId: 'test-empty');
  @override
  Future<CatalogIngredient> get(
    IngredientIdentity identity, {
    String languageCode = 'en',
  }) => throw StateError('Scenario did not provide a remote ingredient');
}

class ExistingLocalIngredientOriginRepository
    implements IngredientOriginRepository {
  const ExistingLocalIngredientOriginRepository();
  @override
  Future<IngredientOriginSnapshot?> read(int localIngredientId) async => null;
  @override
  Future<void> markConfidenceAssessed(int localIngredientId) =>
      throw StateError('Scenario did not provide a confidence write');
}
