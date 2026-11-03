import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';

MealDetailsData mealPreviewFixture({
  int? sourceId,
  int? templateId,
  MealCopySourceData? source,
  List<MealCopyUsageData> usages = const [],
  MealAdvisorDecisionData? decision,
  bool synced = false,
  DateTime? created,
  DateTime? updated,
  DateTime? planned,
  DateTime? summarized,
  List<MealStatusHistoryEntryData> history = const [],
}) {
  final at = DateTime(2026, 11, 3, 12);
  return MealDetailsData(
    meal: MealRecordData(id: 1, name: 'Przykładowy posiłek', status: summarized == null ? 'planned' : 'summarized',
      plannedAt: planned ?? at, summarizedAt: summarized, mealTemplateId: templateId, basedOnMealId: sourceId,
      notes: null, createdAt: created ?? at, updatedAt: updated ?? created ?? at, isSynced: synced),
    advisorDecision: decision, ingredients: const [], plannedSnapshot: null, consumedSnapshot: null,
    statusHistory: history, copySource: source, copyUsages: usages,
  );
}

MealAdvisorDecisionData mealPreviewDecision({DateTime? created, DateTime? updated, String? mode = 'extendedCarbs',
  int grams = 10, int? delay = 5, int? duration = 60, bool manual = false}) {
  final at = created ?? DateTime(2026, 11, 3, 12);
  return MealAdvisorDecisionData(result: manual ? 'manual' : 'bolusWaitThenEat',
    initialWaitTime: 20, finalWaitTime: 15, waitTimeIgnored: false,
    extendedCarbsGrams: grams, extendedCarbsDeliveryMode: mode, extendedCarbsDelayMinutes: delay,
    extendedCarbsDurationMinutes: duration, decisionReason: null, version: 1, isSynced: false,
    createdAt: at, updatedAt: updated ?? at);
}
