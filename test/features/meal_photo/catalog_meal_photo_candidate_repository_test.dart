import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_search_page.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_exception.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/ingredient_catalog/local_ingredient_search_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/unified_ingredient_search_use_case.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/meal_photo/data/catalog_meal_photo_candidate_repository.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_local_ingredient_reader.dart';
import 'package:flutter_test/flutter_test.dart';

const cloudIdentity = IngredientIdentity(
  source: IngredientSource.firebase,
  sourceId: 'usda-1',
);
const frozenMirror = IngredientSearchItem(
  identity: cloudIdentity,
  name: 'Potatoes',
  localIngredientId: 17,
  sourceRevision: 'r1',
);

class PhotoLocalSearch implements LocalIngredientSearchRepository {
  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async => [frozenMirror];
}

class PhotoLocalFacts implements MealPhotoLocalIngredientReader {
  final reads = <int>[];
  @override
  Future<Ingredient> get(int id) async {
    reads.add(id);
    return Ingredient(
      id: id,
      name: 'Old selected potatoes',
      carbsPer100g: 20,
      fiberPer100g: 2,
      fatPer100g: 0,
      proteinPer100g: 2,
      nutritionConfidence: .8,
      isReference: false,
    );
  }
}

class PhotoCatalog implements IngredientCatalogRepository {
  IngredientCatalogFailure? failure;
  int reads = 0;
  @override
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  }) async {
    if (failure case final value?) throw IngredientCatalogException(value);
    return CatalogSearchPage(
      items: [
        const IngredientSearchItem(
          identity: cloudIdentity,
          name: 'New potatoes',
        ),
      ],
      releaseId: 'r1',
    );
  }

  @override
  Future<CatalogIngredient> get(
    IngredientIdentity identity, {
    String languageCode = 'en',
  }) async {
    reads++;
    return CatalogIngredient(
      identity: identity,
      name: 'New potatoes',
      englishName: 'Potatoes',
      revision: 'r2',
      carbsPer100g: 25,
      fiberPer100g: 3,
      fatPer100g: 0,
      proteinPer100g: 2,
      carbsLabelMode: CarbsLabelMode.nonEu,
    );
  }
}

void main() {
  test(
    'mirrored identity hydrates frozen local facts rather than silently adopting new catalog facts',
    () async {
      final catalog = PhotoCatalog();
      final local = PhotoLocalFacts();
      final repository = CatalogMealPhotoCandidateRepository(
        searchUseCase: UnifiedIngredientSearchUseCase(
          local: PhotoLocalSearch(),
          catalog: catalog,
        ),
        catalog: catalog,
        local: local,
      );
      final result = await repository.search('potatoes', languageCode: 'pl');
      expect(result.length, 1);
      expect(result.single.identity, cloudIdentity);
      expect(result.single.localIngredientId, 17);
      expect(result.single.nutritionPer100g.carbs, 20);
      expect(result.single.nutritionConfidence, .8);
      expect(catalog.reads, 0);
      expect(local.reads, [17]);
    },
  );
  test(
    'classified catalog failures preserve local matches and are explicitly reported',
    () async {
      final catalog = PhotoCatalog()
        ..failure = IngredientCatalogFailure.unavailable;
      final failures = <IngredientCatalogException>[];
      final repository = CatalogMealPhotoCandidateRepository(
        searchUseCase: UnifiedIngredientSearchUseCase(
          local: PhotoLocalSearch(),
          catalog: catalog,
        ),
        catalog: catalog,
        local: PhotoLocalFacts(),
        onCatalogFailure: failures.add,
      );
      expect(
        (await repository.search(
          'potatoes',
          languageCode: 'pl',
        )).single.localIngredientId,
        17,
      );
      catalog.failure = IngredientCatalogFailure.invalidResponse;
      expect(
        (await repository.search(
          'potatoes',
          languageCode: 'pl',
        )).single.localIngredientId,
        17,
      );
      catalog.failure = IngredientCatalogFailure.unauthorized;
      expect(
        (await repository.search(
          'potatoes',
          languageCode: 'pl',
        )).single.localIngredientId,
        17,
      );
      expect(failures.map((error) => error.failure), [
        IngredientCatalogFailure.unavailable,
        IngredientCatalogFailure.invalidResponse,
        IngredientCatalogFailure.unauthorized,
      ]);
    },
  );
  test(
    'picker hydration uses exact identity and retains fiber convention and revision',
    () async {
      final catalog = PhotoCatalog();
      final repository = CatalogMealPhotoCandidateRepository(
        searchUseCase: UnifiedIngredientSearchUseCase(
          local: PhotoLocalSearch(),
          catalog: catalog,
        ),
        catalog: catalog,
        local: PhotoLocalFacts(),
      );
      final result = await repository.resolve(
        const IngredientSearchItem(identity: cloudIdentity, name: 'translated'),
        languageCode: 'pl',
      );
      expect(catalog.reads, 1);
      expect(result.catalogRevision, 'r2');
      expect(result.nutritionPer100g.carbs, 25);
      expect(result.nutritionPer100g.fiber, 3);
      expect(result.nutritionPer100g.netCarbs, 22);
      expect(result.nutritionConfidence, isNull);
      expect(result.nutritionConfidenceAssessed, isFalse);
    },
  );
}
