import '../../../common/ingredient_catalog/ingredient_catalog_exception.dart';
import '../../../common/ingredient_catalog/ingredient_catalog_repository.dart';
import '../../../common/ingredient_catalog/ingredient_identity.dart';
import '../../../common/ingredient_catalog/ingredient_match_score.dart';
import '../../../common/ingredient_catalog/ingredient_origin_repository.dart';
import '../../../common/ingredient_catalog/ingredient_search_item.dart';
import '../../../common/ingredient_catalog/selected_catalog_ingredient_store.dart';
import '../../../common/ingredient_catalog/unified_ingredient_search_use_case.dart';
import '../domain/models/meal_photo_candidate.dart';
import '../domain/models/meal_photo_nutrition.dart';
import '../domain/models/meal_photo_review_exception.dart';
import '../domain/ports/meal_photo_candidate_repository.dart';
import 'meal_photo_local_ingredient_reader.dart';

class CatalogMealPhotoCandidateRepository
    implements MealPhotoCandidateRepository {
  const CatalogMealPhotoCandidateRepository({
    required this.searchUseCase,
    required this.catalog,
    required this.local,
    this.onCatalogFailure,
    this.selectedStore,
    this.origins,
  });
  final UnifiedIngredientSearchUseCase searchUseCase;
  final SelectedCatalogIngredientStore? selectedStore;
  final IngredientOriginRepository? origins;
  final IngredientCatalogRepository catalog;
  final MealPhotoLocalIngredientReader local;
  final void Function(IngredientCatalogException)? onCatalogFailure;
  @override
  Future<List<MealPhotoCandidate>> search(
    String query, {
    required String languageCode,
    int limit = 8,
  }) async {
    if (limit < 1 || limit > 30) throw ArgumentError.value(limit, 'limit');
    final localItems = await searchUseCase.searchLocal(query);
    var remoteItems = <IngredientSearchItem>[];
    IngredientCatalogException? catalogFailure;
    try {
      remoteItems = (await searchUseCase.searchCatalog(
        query,
        languageCode,
      )).items;
    } on IngredientCatalogException catch (error) {
      catalogFailure = error;
      onCatalogFailure?.call(error);
    }
    final ranked = UnifiedIngredientSearchUseCase.merge(
      localItems,
      remoteItems,
    ).where((item) => !item.isReference).toList();
    ranked.sort(
      (a, b) => ingredientNameMatchScore(
        query,
        b.name,
        b.englishName,
      ).compareTo(ingredientNameMatchScore(query, a.name, a.englishName)),
    );
    final matchCount = ranked
        .where(
          (item) =>
              ingredientNameMatchScore(query, item.name, item.englishName) >=
              .5,
        )
        .length;
    final items = ranked.take(limit);
    final resolved = await Future.wait(
      items.map((item) async {
        try {
          return (await resolve(
            item,
            languageCode: languageCode,
          )).withMatchCount(matchCount);
        } on MealPhotoReviewException catch (error) {
          if (error.failure !=
              MealPhotoReviewFailure.legacyReferenceUnsupported) {
            rethrow;
          }
          return null;
        } on IngredientCatalogException catch (error) {
          catalogFailure = error;
          onCatalogFailure?.call(error);
          return null;
        }
      }),
    );
    final available = resolved.whereType<MealPhotoCandidate>().toList(
      growable: false,
    );
    if (available.isEmpty && catalogFailure != null) throw catalogFailure!;
    return available;
  }

  Future<MealPhotoCandidate> resolve(
    IngredientSearchItem item, {
    required String languageCode,
  }) async {
    if (item.isReference) {
      throw MealPhotoReviewException(
        MealPhotoReviewFailure.legacyReferenceUnsupported,
      );
    }
    if (item.identity.source == IngredientSource.firebase &&
        selectedStore != null) {
      final localId = await selectedStore!.findLocalId(item.identity);
      if (localId != null) {
        final origin = await origins?.read(localId);
        if (origin == null || origin.sourceRevision == null) {
          throw StateError('Catalog mirror origin is unavailable');
        }
        final value = await local.get(localId);
        return MealPhotoCandidate(
          identity: origin.identity,
          name: value.name,
          localIngredientId: localId,
          catalogRevision: origin.sourceRevision,
          nutritionConfidence: value.nutritionConfidence,
          nutritionConfidenceAssessed: origin.nutritionConfidenceAssessed,
          iconAssetPath: value.iconAssetPath,
          nutritionPer100g: MealPhotoNutrition(
            carbs: value.carbsPer100g,
            fiber: value.fiberPer100g,
            fat: value.fatPer100g,
            protein: value.proteinPer100g,
            carbsLabelMode: value.carbsLabelMode,
          ),
        );
      }
    }
    if (item.identity.source == IngredientSource.local ||
        item.localIngredientId != null) {
      final value = await local.get(
        item.localIngredientId ?? int.parse(item.identity.sourceId),
      );
      if (value.isReference) {
        throw MealPhotoReviewException(
          MealPhotoReviewFailure.legacyReferenceUnsupported,
        );
      }
      return MealPhotoCandidate(
        identity: item.identity,
        name: value.name,
        localIngredientId: value.id,
        catalogRevision: item.sourceRevision,
        nutritionConfidence: value.nutritionConfidence,
        nutritionConfidenceAssessed: item.nutritionConfidenceAssessed,
        iconAssetPath: value.iconAssetPath,
        nutritionPer100g: MealPhotoNutrition(
          carbs: value.carbsPer100g,
          fiber: value.fiberPer100g,
          fat: value.fatPer100g,
          protein: value.proteinPer100g,
          carbsLabelMode: value.carbsLabelMode,
        ),
      );
    }
    final value = await catalog.get(item.identity, languageCode: languageCode);
    return MealPhotoCandidate(
      identity: value.identity,
      name: value.name,
      catalogRevision: value.revision,
      catalogIngredient: value,
      nutritionConfidenceAssessed: false,
      iconAssetPath: value.iconAssetPath,
      nutritionPer100g: MealPhotoNutrition(
        carbs: value.carbsPer100g,
        fiber: value.fiberPer100g,
        fat: value.fatPer100g,
        protein: value.proteinPer100g,
        carbsLabelMode: value.carbsLabelMode,
      ),
    );
  }
}
