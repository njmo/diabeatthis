import 'dart:convert';

import '../../../../common/analysis/dml_semantics.dart';

import '../../domain/models/meal_advisor_input.dart';
import '../../domain/models/meal_advisor_suggestion_policy.dart';

/// Provider-independent protocol; no API credentials or SDK-specific messages.
String mealAdvisorPrompt(
  MealAdvisorInput input, {
  required String language,
  required MealAdvisorSuggestionPolicy policy,
}) {
  if (language != 'pl' && language != 'en') {
    throw ArgumentError.value(language, 'language', 'Unsupported language');
  }
  return '''You are reviewing evidence before a planned meal. Respond in $language.
${dmlSemantics(recordedMeals: input.context.comparisons.isNotEmpty)}

The current meal is planned and has no observed outcome. Read planned_meal, current_before,
current series and earlier similar meals. Compare portions, CGM/trend, IOB/COB, activity,
stress, eCarbs, recorded timing and data quality. Similarity alone cannot justify a timing decision.
Use similar_meals search_status/matched_count/included_count to distinguish empty search from failure.
Never calculate insulin units, dose percentages or recommend settings changes. This is a timing draft for review.
Abstain when evidence is insufficient or contradictory.
Return only one JSON object, exactly these keys:
{"schema_version":1,"request_id":${jsonEncode(input.requestId)},"status":"suggestion|insufficient_data","action":null,"wait_minutes":null,"reason":"brief evidence-based explanation","evidence":[],"missing_data":[]}
For suggestion: action must be one of ${policy.allowedActions.map((a) => a.name).join(', ')}.
Use integer wait_minutes 1..${policy.maximumWaitMinutes} only for bolusWaitThenEat; otherwise use 0.
Maximum input age is ${policy.maximumContextAge.inSeconds} seconds; the application rechecks freshness.
For insufficient_data: action and wait_minutes must be null and missing_data must be nonempty.
Reason <=1000 characters. Evidence and missing_data have at most12 strings, <=200 characters each.
Evidence: existing section IDs or dotted fields; no array indices or invented paths.
A suggestion must cite planned_meal and current_before (or fields within them); historical data alone cannot justify it.
Explain current conditions, reference differences and uncertainty; do not paraphrase statistics.

BEGIN_DML_DATA
${input.text}
END_DML_DATA''';
}
