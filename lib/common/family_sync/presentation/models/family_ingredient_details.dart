import '../../../../core/domain/model/meal.dart';
import '../../../../features/ingredients/data/models/ingredient_details_data.dart'
    as details;
import '../../../../features/ingredients/data/models/ingredient_history_entry_data.dart';
import '../../../../features/ingredients/data/models/ingredient_portion_data.dart';
import '../../../../features/ingredients/data/models/ingredient_usage_data.dart';
import '../../../ingredient_catalog/ingredient_identity.dart';
import '../../../ingredient_catalog/ingredient_origin_repository.dart';
import '../../../nutrition/catalog_nutrition_confidence.dart';
import 'family_ingredient_view.dart';

/// Adapts only the selected child's published records. Never reads local tables.
class FamilyIngredientDetails {
  const FamilyIngredientDetails(this.rows);
  final List<Map<String, dynamic>> rows;

  Iterable<Map> ofKind(String kind) => rows
      .where((row) => row['kind'] == kind && row['deleted'] != true)
      .map((row) => row['payload'] as Map);

  details.IngredientDetailsData? build(int id) {
    final payload = ofKind(
      'ingredients',
    ).where((p) => p['id'] == id).firstOrNull;
    if (payload == null) return null;
    final portions = <IngredientPortionData>[];
    for (final link in ofKind(
      'ingredientPortions',
    ).where((p) => p['ingredient_id'] == id)) {
      final portion = ofKind(
        'portions',
      ).where((p) => p['id'] == link['portion_id']).firstOrNull;
      if (portion == null) return null;
      portions.add(
        IngredientPortionData(
          portionId: portion['id'] as int,
          name: portion['name'] as String,
          unitHint: portion['unit_hint'] as String? ?? '',
          gramsPerPortion: (link['grams_per_portion'] as num).toDouble(),
        ),
      );
    }
    final mealIds = ofKind(
      'mealIngredients',
    ).where((p) => p['ingredient_id'] == id).map((p) => p['meal_id']).toSet();
    final usages = ofKind('meals')
        .where((p) => mealIds.contains(p['id']))
        .map(
          (p) => IngredientUsageData(
            mealId: p['id'] as int,
            name: p['name'] as String,
            purpose: MealPurpose.fromStorage(p['purpose'] as String?),
            description: '',
            plannedAt: DateTime.fromMillisecondsSinceEpoch(
              p['planned_at'] as int,
            ),
            status: p['status'] as String,
          ),
        )
        .toList();
    final history = ofKind('ingredientHistory')
        .where((p) => p['ingredient_id'] == id)
        .map(
          (p) => IngredientHistoryEntryData(
            id: p['id'] as int,
            ingredientId: id,
            carbsPer100g: (p['carbs_per_100g'] as num).toDouble(),
            fatPer100g: (p['fat_per_100g'] as num).toDouble(),
            fiberPer100g: (p['fiber_per_100g'] as num).toDouble(),
            proteinPer100g: (p['protein_per_100g'] as num).toDouble(),
            nutritionConfidence: (p['nutrition_confidence'] as num).toDouble(),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              p['created_at'] as int,
            ),
          ),
        )
        .toList();
    final origin = ofKind(
      'ingredientOrigins',
    ).where((p) => p['ingredient_id'] == id).firstOrNull;
    IngredientOriginSnapshot? snapshot;
    if (origin != null) {
      final identity = IngredientIdentity.fromJson({
        'source': origin['source'],
        'sourceId': origin['source_id'],
      });
      snapshot = IngredientOriginSnapshot(
        localIngredientId: id,
        identity: identity,
        nutritionConfidenceAssessed:
            origin['confidence_origin'] == 'user_assessed',
        creationMethod: origin['creation_method'] as String,
        sourceRevision: origin['source_revision'] as String?,
        englishName: origin['english_name'] as String?,
        displayLanguageCode: origin['display_language_code'] as String?,
        referenceScope: origin['reference_scope'] as String?,
      );
    }
    return fromPayload(
      Map<String, dynamic>.from(payload),
      id: id,
      portions: portions,
      usages: usages,
      history: history,
      origin: snapshot,
    );
  }

  static details.IngredientDetailsData fromPayload(
    Map<String, dynamic> payload, {
    int id = 0,
    List<IngredientPortionData> portions = const [],
    List<IngredientUsageData> usages = const [],
    List<IngredientHistoryEntryData> history = const [],
    IngredientOriginSnapshot? origin,
  }) {
    final item = familyIngredientView({'id': '$id', 'payload': payload});
    final assessed =
        origin?.nutritionConfidenceAssessed ??
        payload['confidence_is_assessed'] as bool? ??
        true;
    return details.IngredientDetailsData(
      ingredient: details.Ingredient(
        id: id,
        name: item.name,
        carbsPer100g: item.carbsPer100g,
        fatPer100g: item.fatPer100g,
        fiberPer100g: item.fiberPer100g,
        proteinPer100g: item.proteinPer100g,
        nutritionConfidence: catalogNutritionConfidence(
          item.nutritionConfidence,
          assessed: assessed,
        ),
        isReference: item.isReference,
        carbsLabelMode: item.carbsLabelMode,
        netKcalPer100g: item.netKcalPer100g,
        kcalPer100g:
            (payload['kcal_per_100g'] as num?)?.toDouble() ?? item.kcalPer100g,
        wbtKcalPer100g: item.wbtKcalPer100g,
        ig: item.ig,
        brand: item.brand,
        barcode: item.barcode,
        iconAssetPath: item.iconAssetPath,
      ),
      portions: portions,
      usages: usages,
      history: history,
      origin: origin,
      confidenceIsAssessed: assessed,
    );
  }
}
