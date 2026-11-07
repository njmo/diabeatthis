import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/details/meal_record_presentation_mapper.dart';
import '../../../../core/drift/database_impl.dart';
import '../models/meal_details_data.dart';
import '../repositories/meal_ingredient_amounts_repository.dart';
import 'ingredient_nutrition_mapper.dart';

class MealDetailsDataMapper extends MealRecordPresentationMapper {
  const MealDetailsDataMapper({required this.db});

  final DatabaseImpl db;

  Future<MealIngredientDetailsData> mapIngredient({
    required MealData meal,
    required MealIngredient mealIngredient,
    required MealSnapshotData? plannedSnapshot,
    required MealSnapshotData? consumedSnapshot,
  }) async {
    final amounts = await MealIngredientAmountsRepository(
      db,
    ).load(mealIngredient);
    final ingredient = amounts.ingredient;
    final gramsPerPortion = amounts.gramsPerPortion;
    final history = await db.ingredientDao.getIngredientStatusHistory(
      ingredient.id,
    );
    const nutritionMapper = IngredientNutritionMapper();
    final portionLabel = await _portionLabel(
      portionId: mealIngredient.portionId,
      gramsPerPortion: gramsPerPortion,
      isReference: ingredient.isReference == 1,
    );

    final mealCreatedAt = date(meal.createdAt);
    final plannedReference = plannedSnapshot == null
        ? mealCreatedAt
        : date(plannedSnapshot.calculatedAt ?? plannedSnapshot.createdAt);
    final consumedReference = consumedSnapshot == null
        ? date(mealIngredient.createdAt)
        : date(consumedSnapshot.calculatedAt ?? consumedSnapshot.createdAt);
    final currentNutrition = nutritionMapper.current(
      ingredient,
      confidenceOverride: mealIngredient.nutritionConfidenceOverride,
    );
    final plannedVersion = nutritionMapper.at(
      ingredient: ingredient,
      history: history,
      reference: plannedReference,
      confidenceOverride: mealIngredient.nutritionConfidenceOverride,
    );
    final consumedVersion = nutritionMapper.at(
      ingredient: ingredient,
      history: history,
      reference: consumedReference,
      confidenceOverride: mealIngredient.nutritionConfidenceOverride,
    );
    return MealIngredientDetailsData(
      mealIngredientId: mealIngredient.id,
      isReference: ingredient.isReference == 1,
      ingredientId: ingredient.id,
      ingredientName: ingredient.name,
      entryType: mealIngredient.entryType,
      portionLabel: portionLabel,
      plannedAmount: amounts.plannedAmount,
      consumedAmount: mealIngredient.consumedAmount,
      quantityConfidence: mealIngredient.quantityConfidence,
      consumedConfidence: mealIngredient.consumedConfidence,
      recordedWeightAvailable: amounts.conversionAvailable,
      plannedTotalGrams: amounts.plannedGrams,
      consumedTotalGrams: amounts.consumedGrams,
      prepMethod: mealIngredient.prepMethod,
      notes: mealIngredient.notes,
      createdAt: date(mealIngredient.createdAt),
      updatedAt: date(mealIngredient.updatedAt),
      currentNutrition: currentNutrition,
      plannedNutrition: plannedVersion.nutrition,
      consumedNutrition: consumedVersion.nutrition,
      plannedNutritionDiffersFromCurrent: plannedVersion.nutrition.differsFrom(
        currentNutrition,
      ),
      consumedNutritionDiffersFromCurrent: consumedVersion.nutrition
          .differsFrom(currentNutrition),
      historicalNutritionUnavailable:
          !amounts.conversionAvailable ||
          plannedVersion.historicalUnavailable ||
          consumedVersion.historicalUnavailable ||
          _hasUnknownCalculationTime(plannedSnapshot) ||
          _hasUnknownCalculationTime(consumedSnapshot),
      plannedHistoricalNutritionUnavailable:
          !amounts.conversionAvailable ||
          plannedVersion.historicalUnavailable ||
          _hasUnknownCalculationTime(plannedSnapshot),
      consumedHistoricalNutritionUnavailable:
          !amounts.conversionAvailable ||
          consumedVersion.historicalUnavailable ||
          _hasUnknownCalculationTime(consumedSnapshot),
    );
  }

  bool _hasUnknownCalculationTime(MealSnapshotData? snapshot) =>
      snapshot != null &&
      snapshot.calculatedAt == null &&
      snapshot.updatedAt != snapshot.createdAt;

  Future<String> _portionLabel({
    required int? portionId,
    required double gramsPerPortion,
    required bool isReference,
  }) async {
    if (isReference) {
      return '100g reference';
    }
    if (portionId == null) {
      return '${_formatNumber(gramsPerPortion)}g';
    }
    final portion = await db.portionDao.getPortionById(portionId);
    if (gramsPerPortion <= 0) {
      return '${portion.name} (${lang.amountMissingPortionWeight})';
    }
    return '${portion.name} (${_formatNumber(gramsPerPortion)}g)';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}
