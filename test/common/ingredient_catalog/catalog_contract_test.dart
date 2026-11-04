import 'dart:async';

import 'package:diabeatthis/common/ingredient_catalog/catalog_callable_transport.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_search_page.dart';
import 'package:diabeatthis/common/ingredient_catalog/firebase_ingredient_catalog_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_exception.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_controller.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/ingredient_catalog/local_ingredient_search_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/unified_ingredient_search_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

const catalogIdentity = IngredientIdentity(
  source: IngredientSource.firebase,
  sourceId: 'usda_123',
);

class CatalogFixtureTransport implements CatalogCallableTransport {
  CatalogFixtureTransport(this.data);
  Map<String, dynamic> data;
  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, Object?> data,
  ) async => this.data;
}

Map<String, dynamic> fixture() => {
  'identity': catalogIdentity.toJson(),
  'ingredient': <String, dynamic>{
    'id': 'usda_123',
    'sourceIngredientId': 'usda_123',
    'nutritionBasisGrams': 100,
    'isReference': false,
    'name': 'Rice, cooked',
    'carbsLabelMode': 'non_eu',
    'carbohydrateDefinition': 'total_including_fiber',
    'carbsPer100g': 28,
    'fiberPer100g': 2,
    'fatPer100g': 1,
    'proteinPer100g': 3,
    'kcalPer100g': 133,
  },
  'display': <String, dynamic>{
    'name': 'Ryż gotowany',
    'languageCode': 'pl',
    'details': '',
  },
};

class ScriptedLocalSearch implements LocalIngredientSearchRepository {
  final requests = <String, Completer<List<IngredientSearchItem>>>{};
  @override
  Future<List<IngredientSearchItem>> search(String query, {int limit = 20}) =>
      (requests[query] = Completer<List<IngredientSearchItem>>()).future;
}

class ScriptedCatalogSearch implements IngredientCatalogRepository {
  final requests = <String, Completer<CatalogSearchPage>>{};
  @override
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  }) => (requests['$query:$languageCode'] = Completer<CatalogSearchPage>())
      .future;
  @override
  Future<CatalogIngredient> get(
    IngredientIdentity identity, {
    String languageCode = 'en',
  }) => throw UnimplementedError();
}

void main() {
  test(
    'US carbohydrates retain fiber separately and subtract it exactly once',
    () async {
      final repository = FirebaseIngredientCatalogRepository(
        CatalogFixtureTransport(fixture()),
      );
      final item = await repository.get(catalogIdentity, languageCode: 'pl');
      expect(item.carbsPer100g, 28);
      expect(item.fiberPer100g, 2);
      expect(item.netCarbsPer100g, 26);
      expect(item.name, 'Ryż gotowany');
      expect(item.englishName, 'Rice, cooked');
    },
  );
  test('translation does not change canonical nutrition revision', () async {
    final transport = CatalogFixtureTransport(fixture());
    final repository = FirebaseIngredientCatalogRepository(transport);
    final polish = await repository.get(catalogIdentity);
    transport.data['display'] = {'name': 'Rice, cooked', 'languageCode': 'en'};
    expect((await repository.get(catalogIdentity)).revision, polish.revision);
  });
  test(
    'unknown fiber and wrong identity cannot become usable nutrition',
    () async {
      for (final key in ['fiberPer100g', 'sourceIngredientId']) {
        final data = fixture();
        (data['ingredient'] as Map).remove(key);
        final repository = FirebaseIngredientCatalogRepository(
          CatalogFixtureTransport(data),
        );
        await expectLater(
          repository.get(catalogIdentity),
          throwsA(isA<IngredientCatalogException>()),
        );
      }
    },
  );
  test('zero carb oil is accepted without fabricated carbohydrate', () async {
    final data = fixture();
    final nutrition = data['ingredient'] as Map<String, dynamic>;
    nutrition['carbsPer100g'] = 0;
    nutrition['fiberPer100g'] = 0;
    nutrition['fatPer100g'] = 100;
    nutrition['proteinPer100g'] = 0;
    final item = await FirebaseIngredientCatalogRepository(
      CatalogFixtureTransport(data),
    ).get(catalogIdentity);
    expect(item.netCarbsPer100g, 0);
    expect(item.fatPer100g, 100);
  });
  test(
    'merging suppresses only identical identity, retaining same-name distinct products',
    () {
      const local = IngredientSearchItem(
        identity: catalogIdentity,
        name: 'Rice',
        localIngredientId: 7,
      );
      const other = IngredientSearchItem(
        identity: IngredientIdentity(
          source: IngredientSource.local,
          sourceId: '8',
        ),
        name: 'Rice',
      );
      expect(
        UnifiedIngredientSearchUseCase.merge([local, other], [local]).length,
        2,
      );
    },
  );
  test(
    'old language responses cannot replace the current query and local survives remote failure',
    () async {
      final local = ScriptedLocalSearch();
      final remote = ScriptedCatalogSearch();
      final controller = IngredientSearchController(
        UnifiedIngredientSearchUseCase(local: local, catalog: remote),
        debounce: Duration.zero,
      );
      addTearDown(controller.dispose);
      controller.search('rice', languageCode: 'en');
      await Future<void>.delayed(Duration.zero);
      controller.search('rice', languageCode: 'pl');
      await Future<void>.delayed(Duration.zero);
      remote.requests['rice:en']!.complete(
        CatalogSearchPage(
          items: [
            const IngredientSearchItem(identity: catalogIdentity, name: 'Old'),
          ],
          releaseId: 'r',
        ),
      );
      local.requests['rice']!.complete([
        const IngredientSearchItem(identity: catalogIdentity, name: 'Local'),
      ]);
      remote.requests['rice:pl']!.completeError(
        const IngredientCatalogException(IngredientCatalogFailure.unavailable),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.items.single.name, 'Local');
      expect(controller.state.languageCode, 'pl');
      expect(
        controller.state.remoteFailure,
        IngredientCatalogFailure.unavailable,
      );
      expect(controller.state.loadingRemote, false);
    },
  );
}
