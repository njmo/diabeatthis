import '../../../../common/analysis/dml_semantics.dart';
import '../../domain/models/meal_ai_result.dart';
import '../../domain/models/meal_dml_document.dart';

const mealAiPromptVersion = 1;
String buildMealAiPrompt(MealDmlDocument document, String language) =>
    '''
Analyze this historical meal for a person with type 1 diabetes or their parent.
Write user-facing text in $language. Return ONLY JSON, without Markdown.

${dmlSemantics()}

Read the target meal, its before snapshot and outcome, then earlier similar meals.
Only the target meal is analyzed; comparisons are context. Compare portions, starting CGM/trend,
IOB/COB, recorded timing, confidence and overlapping food, eCarbs, activity, stress and rescues.
Explain concrete local intervals and event sequences beyond restating dashboard statistics.
A rise already underway before eating cannot be attributed solely to this meal. Check early/late
rises, lows/recovery and the loop response. CGM alone cannot establish absorption or insulin effectiveness.
Suspiciously long workflow waits or overnight stage gaps can be recording issues, not physiology.
Similar ingredients or repeated associations do not prove a causal benefit from waiting.
Separate observations from hypotheses, include alternatives and relevant missing evidence.
Do not diagnose, judge the user, propose insulin doses/percentages, bolus timing or treatment changes.
Use empty summaries/findings when there is no useful additional insight. Do not invent missing history.

Cite actual section IDs or dotted object-field paths; no array indices or wildcards.
Allowed section IDs: ${document.evidenceIds.join(', ')}.
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
