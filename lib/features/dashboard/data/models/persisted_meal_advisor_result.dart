class PersistedMealAdvisorResult {
  final int mealId;
  final String result;
  final int initialWaitTime;
  final int finalWaitTime;
  final bool waitTimeIgnored;
  final int extendedCarbsGrams;
  final String? extendedCarbsDeliveryMode;
  final int? extendedCarbsDelayMinutes;
  final int? extendedCarbsDurationMinutes;
  final int createdAt;

  const PersistedMealAdvisorResult({
    required this.mealId,
    required this.result,
    required this.initialWaitTime,
    required this.finalWaitTime,
    required this.waitTimeIgnored,
    required this.extendedCarbsGrams,
    required this.extendedCarbsDeliveryMode,
    required this.extendedCarbsDelayMinutes,
    required this.extendedCarbsDurationMinutes,
    required this.createdAt,
  });
}
