import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_exception.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/ingredient_catalog/local_ingredient_search_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/unified_ingredient_search_use_case.dart';
import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/meal_photo/data/catalog_meal_photo_candidate_repository.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_local_ingredient_reader.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_review_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_meal_photo_candidate_repository_test.dart';

class PhotoReferenceSearch implements LocalIngredientSearchRepository {
  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async => [
    const IngredientSearchItem(
      identity: IngredientIdentity(
        source: IngredientSource.local,
        sourceId: '1',
      ),
      name: 'Known legacy reference',
      localIngredientId: 1,
      isReference: true,
    ),
    const IngredientSearchItem(
      identity: IngredientIdentity(
        source: IngredientSource.local,
        sourceId: '2',
      ),
      name: 'Stale reference metadata',
      localIngredientId: 2,
    ),
    const IngredientSearchItem(
      identity: IngredientIdentity(
        source: IngredientSource.local,
        sourceId: '3',
      ),
      name: 'Normalized photo reference',
      localIngredientId: 3,
    ),
  ];
}

class PhotoReferenceFacts implements MealPhotoLocalIngredientReader {
  final reads = <int>[];
  @override
  Future<Ingredient> get(int id) async {
    reads.add(id);
    return Ingredient(
      id: id,
      name: id == 3 ? 'Normalized photo reference' : 'Legacy whole portion',
      carbsPer100g: id == 3 ? 12 : 30,
      fiberPer100g: id == 3 ? 1.2 : 0,
      fatPer100g: 1,
      proteinPer100g: 2,
      nutritionConfidence: .6,
      isReference: id != 3,
    );
  }
}

void main() {
  test(
    'LLM candidates omit synthetic legacy references and retain normalized ordinary photo ingredients',
    () async {
      final catalog = PhotoCatalog()
        ..failure = IngredientCatalogFailure.unavailable;
      final local = PhotoReferenceFacts();
      final repository = CatalogMealPhotoCandidateRepository(
        searchUseCase: UnifiedIngredientSearchUseCase(
          local: PhotoReferenceSearch(),
          catalog: catalog,
        ),
        catalog: catalog,
        local: local,
      );
      final result = await repository.search('reference', languageCode: 'en');
      expect(result.length, 1);
      expect(result.single.identity.sourceId, '3');
      expect(result.single.nutritionPer100g.carbs, 12);
      expect(result.single.nutritionPer100g.fiber, 1.2);
      expect(local.reads, [2, 3]);
    },
  );
  test(
    'direct picker hydration rejects current legacy facts before returning any per100g candidate',
    () async {
      final catalog = PhotoCatalog();
      final local = PhotoReferenceFacts();
      final repository = CatalogMealPhotoCandidateRepository(
        searchUseCase: UnifiedIngredientSearchUseCase(
          local: PhotoReferenceSearch(),
          catalog: catalog,
        ),
        catalog: catalog,
        local: local,
      );
      await expectLater(
        repository.resolve(
          const IngredientSearchItem(
            identity: IngredientIdentity(
              source: IngredientSource.local,
              sourceId: '2',
            ),
            name: 'Stale metadata',
            localIngredientId: 2,
          ),
          languageCode: 'en',
        ),
        throwsA(
          isA<MealPhotoReviewException>().having(
            (error) => error.failure,
            'failure',
            MealPhotoReviewFailure.legacyReferenceUnsupported,
          ),
        ),
      );
      expect(local.reads, [2]);
      expect(catalog.reads, 0);
    },
  );
}
