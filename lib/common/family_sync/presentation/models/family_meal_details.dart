import '../../../../core/drift/database_impl.dart';
import '../../../../features/meals/data/mappers/ingredient_nutrition_mapper.dart';
import '../../../../features/meals/data/models/meal_details_data.dart';
import '../../../../features/meals/presentation/models/meal_page_state.dart';
import '../../../presentation/details/meal_record_presentation_mapper.dart';

/// Read-only projection adapter; never constructs a database or writes local rows.
class FamilyMealDetails {
  FamilyMealDetails(this.rows);
  final List<Map<String, dynamic>> rows;
  List<Map> ofKind(String kind) => rows
      .where((r) => r['kind'] == kind && r['deleted'] != true)
      .map((r) => r['payload'] as Map)
      .toList();
  DateTime date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
  double number(Map p, String key) => (p[key] as num).toDouble();

  MealPageState? build(int id, String portionLabel) {
    final meal = ofKind('meals').where((p) => p['id'] == id).firstOrNull;
    if (meal == null) return null;
    final snapshots = ofKind(
      'mealSnapshots',
    ).where((p) => p['meal_id'] == id).toList();
    Map? rawSnapshot(String type) =>
        snapshots.where((s) => s['snapshot_type'] == type).firstOrNull;
    final planned = rawSnapshot('planned');
    final consumed = rawSnapshot('consumed');
    final components = <MealIngredientDetailsData>[];
    for (final item in ofKind(
      'mealIngredients',
    ).where((p) => p['meal_id'] == id)) {
      final raw = ofKind(
        'ingredients',
      ).where((p) => p['id'] == item['ingredient_id']).firstOrNull;
      if (raw == null) {
        return null; // A mirror batch may not yet contain all dependencies.
      }
      final ingredient = IngredientData.fromJson({...raw, 'is_synced': true});
      final history = ofKind('ingredientHistory')
          .where((p) => p['ingredient_id'] == ingredient.id)
          .map(
            (p) => IngredientStatusHistoryData.fromJson(
              Map<String, dynamic>.from(p),
            ),
          )
          .toList();
      const mapper = IngredientNutritionMapper();
      final override = (item['nutrition_confidence_override'] as num?)
          ?.toDouble();
      final current = mapper.current(ingredient, confidenceOverride: override);
      final plannedVersion = mapper.at(
        ingredient: ingredient,
        history: history,
        reference: date(
          planned?['calculated_at'] ??
              planned?['created_at'] ??
              meal['created_at'],
        ),
        confidenceOverride: override,
      );
      final consumedVersion = mapper.at(
        ingredient: ingredient,
        history: history,
        reference: date(
          consumed?['calculated_at'] ??
              consumed?['created_at'] ??
              item['created_at'],
        ),
        confidenceOverride: override,
      );
      final storedWeight = (item['grams_per_portion_used'] as num?)?.toDouble();
      final conversionAvailable =
          storedWeight != null ||
          ingredient.isReference == 1 ||
          item['portion_id'] == null;
      final factor =
          storedWeight ??
          (ingredient.isReference == 1
              ? 100.0
              : item['portion_id'] == null
              ? 1.0
              : 0.0);
      final plannedAmount = item['entry_type'] == 'extra'
          ? 0.0
          : number(item, 'amount');
      final consumedAmount = (item['consumed_amount'] as num?)?.toDouble();
      final portion = ofKind(
        'portions',
      ).where((p) => p['id'] == item['portion_id']).firstOrNull;
      components.add(
        MealIngredientDetailsData(
          mealIngredientId: item['id'] as int,
          isReference: ingredient.isReference == 1,
          ingredientId: ingredient.id,
          ingredientName: ingredient.name,
          entryType: item['entry_type'] as String,
          portionLabel: portion?['name'] as String? ?? portionLabel,
          plannedAmount: plannedAmount,
          consumedAmount: consumedAmount,
          quantityConfidence: number(item, 'quantity_confidence'),
          consumedConfidence: (item['consumed_confidence'] as num?)?.toDouble(),
          recordedWeightAvailable: conversionAvailable,
          plannedTotalGrams: plannedAmount * factor,
          consumedTotalGrams: (consumedAmount ?? plannedAmount) * factor,
          prepMethod: item['prep_method'] as String?,
          notes: item['notes'] as String?,
          createdAt: date(item['created_at']),
          updatedAt: date(item['updated_at']),
          currentNutrition: current,
          plannedNutrition: plannedVersion.nutrition,
          consumedNutrition: consumedVersion.nutrition,
          plannedNutritionDiffersFromCurrent: plannedVersion.nutrition
              .differsFrom(current),
          consumedNutritionDiffersFromCurrent: consumedVersion.nutrition
              .differsFrom(current),
          historicalNutritionUnavailable: false,
          plannedHistoricalNutritionUnavailable:
              !conversionAvailable ||
              plannedVersion.historicalUnavailable ||
              (planned != null &&
                  planned['calculated_at'] == null &&
                  planned['updated_at'] != planned['created_at']),
          consumedHistoricalNutritionUnavailable:
              !conversionAvailable ||
              consumedVersion.historicalUnavailable ||
              (consumed != null &&
                  consumed['calculated_at'] == null &&
                  consumed['updated_at'] != consumed['created_at']),
        ),
      );
    }
    final history =
        ofKind('mealHistory')
            .where((p) => p['meal_id'] == id)
            .map(
              (p) => MealStatusHistoryEntryData(
                id: p['id'] as int,
                mealId: id,
                status: p['status'] as String,
                createdAt: date(p['created_at']),
              ),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    const records = MealRecordPresentationMapper();
    MealSnapshotDetailsData? snapshot(Map? p) => p == null
        ? null
        : records.mapSnapshot(
            MealSnapshotData.fromJson({...p, 'is_synced': true}),
          );
    // Recorded whole-meal totals come from the child's saved snapshots,
    // never from a potentially partial list of mirrored ingredient links.
    return MealPageState(
      details: MealDetailsData(
        meal: records.mapMeal(MealData.fromJson({...meal, 'is_synced': true})),
        advisorDecision: null,
        ingredients: components,
        plannedSnapshot: snapshot(planned),
        consumedSnapshot: snapshot(consumed),
        plannedPreviewNutrition: null,
        statusHistory: history,
      ),
    );
  }
}
