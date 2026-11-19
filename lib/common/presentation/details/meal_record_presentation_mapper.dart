import '../../../core/drift/database_impl.dart';
import '../../../features/meals/data/models/meal_details_data.dart';
import '../../meal/meal_completion_decision.dart';

/// Pure record mapping shared by local loaders and cloud projection adapters.
class MealRecordPresentationMapper {
  const MealRecordPresentationMapper();
  MealRecordData mapMeal(MealData meal) {
    return MealRecordData(
      id: meal.id,
      category: meal.category,
      name: meal.name,
      purpose: meal.purpose,
      status: meal.status,
      plannedAt: meal.plannedAt == null ? null : date(meal.plannedAt!),
      plannedDay: meal.plannedDay,
      summarizedAt: meal.summarizedAt == null ? null : date(meal.summarizedAt!),
      mealTemplateId: meal.mealTemplateId,
      basedOnMealId: meal.basedOnMealId,
      notes: meal.notes,
      createdAt: date(meal.createdAt),
      updatedAt: date(meal.updatedAt),
      isSynced: meal.isSynced,
      completionDecision: MealCompletionDecision.decode(
        meal.completionDecision,
      ),
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

  DateTime date(int millisecondsSinceEpoch) {
    return DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  }
}
