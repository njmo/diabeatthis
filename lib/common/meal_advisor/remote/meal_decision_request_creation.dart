import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../meal_decision_preferences.dart';

const scheduledCaregiverRequestLeadTime = Duration(minutes: 20);

String scheduledMealDecisionRequestId(
  String sourceId,
  int mealId,
  int plannedAtMillis,
) => sha256
    .convert(utf8.encode('$sourceId:$mealId:$plannedAtMillis'))
    .toString()
    .substring(0, 32);

Map<String, Object?> mealDecisionCreationData({
  required String requestId,
  required int mealId,
  required String sourceId,
  required MealDecisionPreferences preferences,
}) => {
  'requestId': requestId,
  'mealId': '$mealId',
  'sourceId': sourceId,
  'timeoutFallback': preferences.timeoutFallback.name,
  'allowManualDecision': preferences.allowManualDecision,
};
