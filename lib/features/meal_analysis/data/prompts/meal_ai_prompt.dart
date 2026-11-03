import '../../../../common/analysis/dml_semantics.dart';
import '../../../../common/analysis/nutrition_revision_semantics.dart';
import '../../domain/models/meal_ai_result.dart';
import '../../domain/models/meal_dml_document.dart';

const mealAiPromptVersion = 4;
String buildMealAiPrompt(MealDmlDocument document, String language) =>
    '''
Analyze this historical meal for a person with type 1 diabetes or their parent.
Write user-facing text in $language. Return ONLY JSON, without Markdown.

${dmlSemantics()}

Analyze only the target meal's before snapshot and outcome; earlier similar meals are context.
Compare portions, starting CGM/trend, IOB/COB, recorded timing, confidence, overlapping food,
eCarbs, activity, stress and rescues. Explain local intervals and event sequences, not just statistics.
Check pre-existing/early/late rises, lows/recovery and loop response; a pre-existing rise is not
solely meal-related. CGM cannot establish absorption or insulin effectiveness. Long waits/overnight
stage gaps may be recording issues. Similar ingredients/repeated associations do not prove waiting helps.
Separate observations/hypotheses, alternatives and missing evidence. Never diagnose, judge, suggest
insulin doses/percentages, bolus timing or treatment changes, repeat numbers/episodes or invent history.
Overview: takeaway. Before: preconditions. Response: episode. Comparison: differences/limits.
Empty summaries/findings are valid.
${nutritionRevisionSemantics(document.evidenceIds.any((id) => id.endsWith('_nutrition_revisions')))}

Cite these section IDs or their exact dotted JSON object paths: ${document.evidenceIds.join(', ')}.
Never invent/flatten paths or use array indices/wildcards; cite arrays as a whole (meal_cgm.blocks).
Eating timestamps are nested: meal.recorded_timing.eating_started_at.
JSON shape: {"schema_version":1,"language":"$language","sections":{
"overview":SECTION,"before":SECTION,"response":SECTION,"comparison":SECTION}}
SECTION: {"status":"ok" or "insufficient_data","summary":"max 320 characters","findings":[],"missing_data":[]}
At most ONE finding per section; missing_data: at most 12 strings, max 160 characters each.
Finding: {"title":"max 80 characters","text":"max ${MealAiResult.findingTextLimit} characters",
"kind":"observation" or "hypothesis","confidence":"low" or "medium" or "high","evidence_refs":["existing_id"]}.
Each finding needs 1..${MealAiResult.evidenceRefsLimit} actual references. Confidence is qualitative, not a calibrated probability.
All response fields are required; no additional keys. Before answering verify chronology and ranges.

BEGIN_DML_DATA
${document.text}
END_DML_DATA
''';
