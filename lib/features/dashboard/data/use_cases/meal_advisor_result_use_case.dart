import '../../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import '../models/persisted_meal_advisor_result.dart';
import '../repositories/meal_advisor_result_store.dart';
import '../utils/meal_advisor.dart';

class MealAdvisorResultUseCase {
  final MealAdvisorResultStore store;

  const MealAdvisorResultUseCase(this.store);

  Future<MealAdvice?> loadMealAdvice(int mealId) async {
    final result = await store.getMealAdvisorResult(mealId);
    if (result == null) return null;

    return MealAdvice.full(
      _decisionFromStatus(result.result),
      result.waitTimeIgnored
          ? null
          : WaitSuggestion(result.initialWaitTime, 0, 0),
      DateTime.fromMillisecondsSinceEpoch(result.createdAt),
      extendedCarbs: _extendedCarbsFromResult(result),
    );
  }

  Future<int> saveMealAdvice(int mealId, MealAdvice advice) {
    final decision = advice.decision;
    if (decision == null) {
      throw StateError('Cannot save meal advice without a decision.');
    }

    final waitTime = advice.wait?.recommendedMinutes ?? 0;
    final shouldSuggestExtendedCarbs = advice.extendedCarbs.shouldSuggest;
    final scheduleSettings = advice.extendedCarbs.scheduleSettings;

    return store.insertMealAdvisorResult(
      PersistedMealAdvisorResult(
        mealId: mealId,
        result: decision.status,
        finalWaitTime: waitTime,
        initialWaitTime: waitTime,
        waitTimeIgnored: advice.wait == null,
        extendedCarbsGrams: advice.extendedCarbs.grams,
        extendedCarbsDeliveryMode: shouldSuggestExtendedCarbs
            ? scheduleSettings.deliveryMode.name
            : null,
        extendedCarbsDelayMinutes: shouldSuggestExtendedCarbs
            ? scheduleSettings.delayMinutes
            : null,
        extendedCarbsDurationMinutes: shouldSuggestExtendedCarbs
            ? scheduleSettings.durationMinutes
            : null,
        createdAt: advice.createdAt.millisecondsSinceEpoch,
      ),
    );
  }

  WbtExtendedCarbsSuggestion _extendedCarbsFromResult(
    PersistedMealAdvisorResult result,
  ) {
    if (result.extendedCarbsGrams <= 0) {
      return const WbtExtendedCarbsSuggestion.none();
    }

    final scheduleSettings = _scheduleSettingsFromResult(result);

    return WbtExtendedCarbsSuggestion(
      kcal: 0,
      wbt: 0,
      grams: result.extendedCarbsGrams,
      scheduleSettings:
          scheduleSettings ?? const ExtendedCarbsScheduleSettings.defaults(),
    );
  }

  ExtendedCarbsScheduleSettings? _scheduleSettingsFromResult(
    PersistedMealAdvisorResult result,
  ) {
    final deliveryMode = result.extendedCarbsDeliveryMode;
    final delayMinutes = result.extendedCarbsDelayMinutes;
    final durationMinutes = result.extendedCarbsDurationMinutes;

    if (deliveryMode == null ||
        delayMinutes == null ||
        durationMinutes == null) {
      return null;
    }

    return ExtendedCarbsScheduleSettings(
      deliveryMode: _deliveryModeFromStorage(deliveryMode),
      delayMinutes: delayMinutes,
      durationMinutes: durationMinutes,
    );
  }

  MealDecision _decisionFromStatus(String status) {
    return switch (status) {
      'eating-then-bolus' => MealDecision.eatNowBolusLater,
      'bolused-eating' => MealDecision.bolusAndEatNow,
      'bolused-waiting' => MealDecision.bolusWaitThenEat,
      _ => MealDecision.bolusAndEatNow,
    };
  }

  ExtendedCarbsDeliveryMode _deliveryModeFromStorage(String value) {
    return ExtendedCarbsDeliveryMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ExtendedCarbsDeliveryMode.extendedCarbs,
    );
  }
}
