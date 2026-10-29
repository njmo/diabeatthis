import '../../../../common/analysis/dml_semantics.dart';
import '../../domain/models/day_analysis_result.dart';
import '../../domain/models/day_dml_document.dart';

const dayAnalysisPromptVersion = 1;

String buildDayAnalysisPrompt(DayDmlDocument document, String language) =>
    '''
Analyze an accepted diabetes day summary. Output JSON only, in language $language.
Cite actual section IDs in evidence_refs. Each JSON section carries its id.

${dmlSemantics(acceptedSummary: true)}

Day-specific context:
- DAY/GLUCOSE/INSULIN/NIGHT/MEALS/QUALITY are accepted aggregates; HISTORY and the series are current
  reconstruction. Coverage/limitations apply separately. Night may overlap the day.
- GLUCOSE/NIGHT range percentages use observed CGM time; coverage_pct uses the whole window.
  Means are time weighted. Equipment *_age_minutes_at_as_of is age at cutoff, not midnight.
- MEALS.count counts started/eaten LOCAL entries, not calculator submissions or necessarily finished meals.
  Planned/partial macros and absent local records do not establish total food intake.
- REVIEW rows are reconciliation entries, not a clinical timeline or deliveries. Multiple rows can share
  a meal_ref; carbohydrate_entry is a candidate, not necessarily a confirmed rescue. Never count rows as meals.
- PREVIOUS_DAYS contains up to seven accepted local calendar dates, not previous AI opinions.
  days=null means unavailable; days=[] means no summaries. Never invent/interpolate missing days.
  Metrics use *Percent, *Units, *Grams, *Minutes, *Count and glucose mg/dl. Compare only available,
  comparable metrics with their own coverage. Accepted wall times use archived offsets, HISTORY uses device time.
- Read the selected night interval/NIGHT_COURSE, global CGM/PUMP/BOLUSES/events and MEAL windows together.
  Night lead_in=null is unknown. Inspect preceding MEAL analyze=false before claiming missing evening context.
- MEAL analyze=true needs a section under its exact id; other meals provide context.
  Windows of 90 minutes/3 hours are observation policy, not absorption deadlines. They can extend into
  tomorrow and overlap; shared events/totals must not be counted twice. outcome.start_at is the baseline's
  exact time, which may follow eating. Before snapshots use the same semantics as individual meal analysis.

Analysis objective:
Help a parent or person with type 1 diabetes understand consequential episodes, without blame or grades.
Overview gives the most important takeaway, not a numeric recap. Then place episode detail in its meal,
night or activity section. Do not repeat it across sections or paraphrase dashboard means/TIR/macros/age.
For each meal inspect the pre-existing trend, recorded eating/bolus sequence, early/late rises,
lows/recovery and basal/SMB response. Consider previous eCarbs, later food, exercise, rescues,
stress and temporary targets as alternative explanations. Match local times and dates before attribution.
For night locate unstable intervals, SMB clusters and subsequent recovery. SMB alone does not prove
inadequate basal or site failure. Basal reduction/suspension is a response, not proof it caused a fall.
A maximum already present before eating cannot establish that meal's effect. CGM alone cannot prove
absorption exceeded insulin action. Long waits/eating durations may reflect late app interactions;
distinguish a recording issue from physiology. Equipment age alone cannot establish lifespan, accuracy
or failure: keep devices findings empty unless supported by device-specific facts/measurements.
A useful finding names an interval and observed sequence. Use a hypothesis with low/medium confidence
for causal interpretations; provide plausible alternatives. Avoid generic mechanisms or invented context.
Do not diagnose, recommend doses, percentages, bolus schedules or treatment settings.
Summaries/findings may be empty. Missing_data names relevant unavailable evidence, without repeating
all QUALITY/HISTORY limitations. Verify chronological_points against CGM; selected points are not a trend.
This is a review draft, not a treatment decision or an accepted analysis.

Exact response shape:
{"schema_version":${DayAnalysisResult.schemaVersion},"language":"$language","sections":{
  ${[...DayAnalysisResult.sectionNames, ...document.meals.keys].map((name) => '"$name":{"status":"ok","summary":"","findings":[],"missing_data":[]}').join(',\n  ')}
}}
Every section must be present. No additional keys.
status: "ok" or "insufficient_data". summary: aim for 160 characters, hard limit 320.
At most ONE finding per section, exactly:
{"title":"aim for 50 chars, hard limit 80","text":"aim for 400 chars, hard limit 600","kind":"observation",
 "confidence":"medium","evidence_refs":["glucose"]}
kind: observation|hypothesis. confidence: low|medium|high (qualitative, not calibrated probability).
Each finding needs 1–8 existing evidence ids. missing_data: 0–12 short strings naming unavailable facts.
Keep the complete response compact. Prioritize concrete observations over lengthy prose.
Do not reproduce every statistic. Prioritize the useful observations and limitations.

BEGIN_DML_DATA
${document.text}END_DML_DATA
''';
