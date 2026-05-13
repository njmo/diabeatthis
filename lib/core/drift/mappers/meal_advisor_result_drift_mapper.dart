import 'package:drift/drift.dart';

import '../../../features/dashboard/data/models/persisted_meal_advisor_result.dart';
import '../database_impl.dart';

class MealAdvisorResultDriftMapper {
  const MealAdvisorResultDriftMapper();

  PersistedMealAdvisorResult fromData(MealAdvisorResultData data) {
    return PersistedMealAdvisorResult(
      mealId: data.mealId,
      result: data.result,
      initialWaitTime: data.initialWaitTime,
      finalWaitTime: data.finalWaitTime,
      waitTimeIgnored: data.waitTimeIgnored,
      extendedCarbsGrams: data.extendedCarbsGrams,
      extendedCarbsDeliveryMode: data.extendedCarbsDeliveryMode,
      extendedCarbsDelayMinutes: data.extendedCarbsDelayMinutes,
      extendedCarbsDurationMinutes: data.extendedCarbsDurationMinutes,
      createdAt: data.createdAt,
    );
  }

  MealAdvisorResultCompanion toCompanion(PersistedMealAdvisorResult result) {
    return MealAdvisorResultCompanion(
      mealId: Value(result.mealId),
      result: Value(result.result),
      initialWaitTime: Value(result.initialWaitTime),
      finalWaitTime: Value(result.finalWaitTime),
      waitTimeIgnored: Value(result.waitTimeIgnored),
      extendedCarbsGrams: Value(result.extendedCarbsGrams),
      extendedCarbsDeliveryMode: Value(result.extendedCarbsDeliveryMode),
      extendedCarbsDelayMinutes: Value(result.extendedCarbsDelayMinutes),
      extendedCarbsDurationMinutes: Value(result.extendedCarbsDurationMinutes),
      version: const Value(2),
    );
  }
}
