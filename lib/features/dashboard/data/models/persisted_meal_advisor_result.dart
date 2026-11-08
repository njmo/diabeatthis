class PersistedMealAdvisorResult {
  String get source =>
      decisionSource ?? (result == 'manual' ? 'manual' : 'mealAdvisor');
  final String? decisionSource;
  final String? caregiverId;
  final String? caregiverRequestId;
  final int mealId;
  final String? decisionReason;
  final int? version;
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
    this.decisionSource,
    this.caregiverId,
    this.caregiverRequestId,
    this.decisionReason,
    this.version = 2,
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
