import 'dart:convert';

import '../../../../common/analysis/dml_aaps_context.dart';
import '../../../../common/analysis/dml_time_blocks.dart';
import '../../../../common/analysis/dml_timestamp.dart';
import '../../../../common/analysis/dml_treatment_context.dart';
import '../../../../core/domain/model/correction_bolus.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../meal_analysis/domain/models/before_meal_context.dart';
import '../../../meal_analysis/domain/serialization/meal_observation_dml.dart';
import '../../../meal_analysis/domain/serialization/meal_record_evidence_dml.dart';
import '../models/meal_advisor_context.dart';
import '../models/meal_advisor_input.dart';

MealAdvisorInput serializeMealAdvisorContext(
  MealAdvisorContext context, {
  required String requestId,
}) {
  final before = context.before;
  final target = context.target;
  final ids = <String>{};
  final lines = <String>['DML/1'];
  void add(String id, Map<String, Object?> facts) {
    ids.add(id);
    lines.add('$id ${jsonEncode(facts)}');
  }

  add('context', {
    'scope': 'before_meal_advisor',
    'request_id': requestId,
    'as_of': dmlTimestamp(before.asOf),
    'built_at': dmlTimestamp(context.builtAt),
    'failed_optional_sources': context.failures.toList(),
    'current_meal_is_planned': true,
    'history_semantics':
        'Event-time reconstruction from currently available records; original upload times and revisions are unavailable.',
    'reading_order': [
      'planned_meal',
      'current_before',
      'current_cgm',
      'current_aaps',
      'current_insulin',
      'similar_meals',
    ],
    'interpretation_limits': [
      'Current meal has no observed outcome. Historical references must end before as_of.',
      'Ingredient similarity does not establish equal preconditions or causal benefit from waiting.',
      'Missing waiting, delivery or confidence is unknown, never zero or high confidence.',
    ],
  });
  add(
    'planned_meal',
    target == null
        ? {'available': false}
        : {
            'available': true,
            'name': target.name,
            'scheduled_at': dmlTimestamp(target.plannedAt),
            'macro_source': 'current_planned_amounts',
            'net_carbs_g': target.macros.netCarbsGrams,
            'protein_g': target.macros.proteinGrams,
            'fat_g': target.macros.fatGrams,
            'fiber_g': target.macros.fiberGrams,
            'ingredients': [
              for (final i in target.ingredients) [i.name, i.grams],
            ],
            'nutrition_confidence': mealNutritionConfidenceDml(
              target.confidence,
            ),
          },
  );
  add('current_before', beforeMealFactsDml(before));
  add('current_cgm', {
    'columns': ['time', 'mg_dl', 'direction'],
    'blocks': dmlTimeBlocks(
      before.glucose?.map((g) => (at: g.date, values: [g.sgv, g.direction])),
    ),
  });
  final insulinStart = before.asOf.subtract(before.windows.insulin);
  add(
    'current_aaps',
    dmlAapsContext(
      statuses: before.failedSources.contains(BeforeMealSource.deviceStatus)
          ? null
          : [if (before.latestDeviceStatus != null) before.latestDeviceStatus!],
      treatments: before.treatments,
      start: insulinStart,
      end: before.asOf,
    ),
  );
  add('current_insulin', {
    'columns': ['time', 'kind', 'recorded_units'],
    'blocks': dmlTimeBlocks(
      before.treatments == null
          ? null
          : [
              for (final t in before.treatments!)
                if (t.isValid &&
                    t.createdAt != null &&
                    !t.createdAt!.isBefore(insulinStart) &&
                    !t.createdAt!.isAfter(before.asOf))
                  if (t is ManualBolus && t.insulin.isFinite && t.insulin > 0)
                    (at: t.createdAt, values: ['manual', t.insulin])
                  else if (t is CorrectionBolus &&
                      t.insulin.isFinite &&
                      t.insulin > 0)
                    (at: t.createdAt, values: ['smb', t.insulin]),
            ],
    ),
  });
  for (final section in dmlTreatmentContext(
    treatments: before.treatments,
    glucose: before.glucose,
    start: before.asOf.subtract(before.windows.meals),
    historyStart: before.asOf.subtract(before.windows.meals),
    end: before.asOf,
  )) {
    add('current_${section.id}', section.facts);
  }
  for (final entry in context.comparisons.indexed) {
    final prefix = 'similar_${entry.$1 + 1}';
    add('${prefix}_match', {
      'same_ingredients': entry.$2.match.matchesIngredients,
      'portion_ratio_reference_to_current': entry.$2.match.portionRatio,
      'macro_or_composition_distance': entry.$2.match.distance,
      'starting_conditions_must_be_compared_separately': true,
    });
    appendMealObservationDml(add, prefix, entry.$2.observation);
  }
  return MealAdvisorInput(
    context: context,
    requestId: requestId,
    text: lines.join('\n'),
    evidenceIds: ids,
  );
}
