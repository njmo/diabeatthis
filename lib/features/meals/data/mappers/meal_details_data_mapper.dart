import '../../../../core/drift/database_impl.dart';
import '../models/meal_details_data.dart';
import '../repositories/meal_ingredient_amounts_repository.dart';
import 'ingredient_nutrition_mapper.dart';

class MealDetailsDataMapper {
  const MealDetailsDataMapper({required this.db});

  final DatabaseImpl db;

  MealRecordData mapMeal(MealData meal) {
    return MealRecordData(
      id: meal.id,
      name: meal.name,
      purpose: meal.purpose,
      status: meal.status,
      plannedAt: date(meal.plannedAt),
      summarizedAt: meal.summarizedAt == null ? null : date(meal.summarizedAt!),
      mealTemplateId: meal.mealTemplateId,
      basedOnMealId: meal.basedOnMealId,
      notes: meal.notes,
      createdAt: date(meal.createdAt),
      updatedAt: date(meal.updatedAt),
      isSynced: meal.isSynced,
    );
  }

  MealAdvisorDecisionData mapAdvisorDecision(MealAdvisorResultData decision) {
    return MealAdvisorDecisionData(
      result: decision.result,
      initialWaitTime: decision.initialWaitTime,
      finalWaitTime: decision.finalWaitTime,
      waitTimeIgnored: decision.waitTimeIgnored,
      extendedCarbsGrams: decision.extendedCarbsGrams,
      extendedCarbsDeliveryMode: decision.extendedCarbsDeliveryMode,
      extendedCarbsDelayMinutes: decision.extendedCarbsDelayMinutes,
      extendedCarbsDurationMinutes: decision.extendedCarbsDurationMinutes,
      decisionReason: decision.decisionReason,
      version: decision.version,
      isSynced: decision.isSynced,
      createdAt: date(decision.createdAt),
      updatedAt: date(decision.updatedAt),
    );
  }

  MealSnapshotDetailsData mapSnapshot(MealSnapshotData snapshot) {
    return MealSnapshotDetailsData(
      id: snapshot.id,
      mealId: snapshot.mealId,
      snapshotType: snapshot.snapshotType,
      totalGrams: snapshot.totalGrams,
      totalCarbsG: snapshot.totalCarbsG,
      totalFiberG: snapshot.totalFiberG,
      totalNetCarbsG: snapshot.totalNetCarbsG,
      totalFatG: snapshot.totalFatG,
      totalProteinG: snapshot.totalProteinG,
      totalCaloriesKcal: snapshot.totalCaloriesKcal,
      ingredientsCount: snapshot.ingredientsCount,
      avgQuantityConfidence: snapshot.avgQuantityConfidence,
      minQuantityConfidence: snapshot.minQuantityConfidence,
      carbWeightedQuantityConfidence: snapshot.carbWeightedQuantityConfidence,
      wbtWeightedQuantityConfidence: snapshot.wbtWeightedQuantityConfidence,
      carbWeightedNutritionConfidence: snapshot.carbWeightedNutritionConfidence,
      wbtWeightedNutritionConfidence: snapshot.wbtWeightedNutritionConfidence,
      carbWeightedEffectiveConfidence: snapshot.carbWeightedEffectiveConfidence,
      wbtWeightedEffectiveConfidence: snapshot.wbtWeightedEffectiveConfidence,
      createdAt: date(snapshot.createdAt),
      updatedAt: date(snapshot.updatedAt),
      isSynced: snapshot.isSynced,
    );
  }

  MealStatusHistoryEntryData mapStatusHistory(MealStatusHistoryData history) {
    return MealStatusHistoryEntryData(
      id: history.id,
      mealId: history.mealId,
      status: history.status,
      createdAt: date(history.createdAt),
    );
  }

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
        : date(plannedSnapshot.createdAt);
    final consumedReference = consumedSnapshot == null
        ? date(mealIngredient.createdAt)
        : date(consumedSnapshot.createdAt);
    final currentNutrition = nutritionMapper.current(ingredient);
    final plannedVersion = nutritionMapper.at(
      ingredient: ingredient,
      history: history,
      reference: plannedReference,
    );
    final consumedVersion = nutritionMapper.at(
      ingredient: ingredient,
      history: history,
      reference: consumedReference,
    );
    return MealIngredientDetailsData(
      mealIngredientId: mealIngredient.id,
      ingredientId: ingredient.id,
      ingredientName: ingredient.name,
      entryType: mealIngredient.entryType,
      portionLabel: portionLabel,
      plannedAmount: amounts.plannedAmount,
      consumedAmount: mealIngredient.consumedAmount,
      quantityConfidence: mealIngredient.quantityConfidence,
      consumedConfidence: mealIngredient.consumedConfidence,
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
          plannedVersion.historicalUnavailable ||
          consumedVersion.historicalUnavailable,
    );
  }

  DateTime date(int millisecondsSinceEpoch) {
    return DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  }

  Future<String> _portionLabel({
    required int? portionId,
    required double gramsPerPortion,
    required bool isReference,
  }) async {
    if (isReference) {
      return '100g reference';
    }
    if (portionId == null) {
      return '1g';
    }
    final portion = await db.portionDao.getPortionById(portionId);
    return '${portion.name} (${_formatNumber(gramsPerPortion)}g)';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}
