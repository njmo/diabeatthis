import '../../../../core/drift/database_impl.dart';
import '../models/meal_details_data.dart';

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
    final ingredient = await db.ingredientDao.getIngredientById(
      mealIngredient.ingredientId,
    );
    final history = await db.ingredientDao.getIngredientStatusHistory(
      ingredient.id,
    );
    final gramsPerPortion = await _gramsPerPortion(
      ingredientId: ingredient.id,
      portionId: mealIngredient.portionId,
      isReference: ingredient.isReference == 1,
    );
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
    final currentNutrition = _currentNutrition(ingredient);
    final plannedVersion = _nutritionAt(
      ingredient: ingredient,
      history: history,
      reference: plannedReference,
    );
    final consumedVersion = _nutritionAt(
      ingredient: ingredient,
      history: history,
      reference: consumedReference,
    );
    final plannedAmount = mealIngredient.entryType == 'extra'
        ? 0.0
        : mealIngredient.amount;
    final consumedAmount = mealIngredient.entryType == 'extra'
        ? (mealIngredient.consumedAmount ?? 0)
        : (mealIngredient.consumedAmount ?? mealIngredient.amount);

    return MealIngredientDetailsData(
      mealIngredientId: mealIngredient.id,
      ingredientId: ingredient.id,
      ingredientName: ingredient.name,
      entryType: mealIngredient.entryType,
      portionLabel: portionLabel,
      plannedAmount: plannedAmount,
      consumedAmount: mealIngredient.consumedAmount,
      quantityConfidence: mealIngredient.quantityConfidence,
      consumedConfidence: mealIngredient.consumedConfidence,
      plannedTotalGrams: plannedAmount * gramsPerPortion,
      consumedTotalGrams: consumedAmount * gramsPerPortion,
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

  Future<double> _gramsPerPortion({
    required int ingredientId,
    required int? portionId,
    required bool isReference,
  }) async {
    if (isReference) {
      return 100;
    }
    if (portionId == null) {
      return 1;
    }
    return await db.portionDao.getGramsPerPortion(ingredientId, portionId) ?? 1;
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

  _ResolvedNutrition _nutritionAt({
    required IngredientData ingredient,
    required List<IngredientStatusHistoryData> history,
    required DateTime reference,
  }) {
    final sorted = history.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    IngredientStatusHistoryData? selected;
    for (final entry in sorted) {
      if (date(entry.createdAt).isAfter(reference)) {
        break;
      }
      selected = entry;
    }

    if (selected != null) {
      return _ResolvedNutrition(
        nutrition: IngredientNutritionData(
          carbsPer100g: selected.carbsPer100g,
          fatPer100g: selected.fatPer100g,
          fiberPer100g: selected.fiberPer100g,
          proteinPer100g: selected.proteinPer100g,
          nutritionConfidence: selected.nutritionConfidence,
          effectiveAt: date(selected.createdAt),
        ),
        historicalUnavailable: false,
      );
    }

    final current = _currentNutrition(ingredient);
    final changedAfterReference = history.any(
      (entry) => date(entry.createdAt).isAfter(reference),
    );
    return _ResolvedNutrition(
      nutrition: current,
      historicalUnavailable:
          changedAfterReference &&
          date(ingredient.updatedAt).isAfter(reference),
    );
  }

  IngredientNutritionData _currentNutrition(IngredientData ingredient) {
    return IngredientNutritionData(
      carbsPer100g: ingredient.carbsPer100g,
      fatPer100g: ingredient.fatPer100g,
      fiberPer100g: ingredient.fiberPer100g,
      proteinPer100g: ingredient.proteinPer100g,
      nutritionConfidence: ingredient.nutritionConfidence,
      effectiveAt: date(ingredient.updatedAt),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _ResolvedNutrition {
  const _ResolvedNutrition({
    required this.nutrition,
    required this.historicalUnavailable,
  });

  final IngredientNutritionData nutrition;
  final bool historicalUnavailable;
}
