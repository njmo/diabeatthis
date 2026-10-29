import '../../../../common/analysis/dml_aaps_context.dart';
import '../../../../common/analysis/dml_insulin_records.dart';
import '../../../../common/analysis/dml_json.dart';
import '../../../../common/analysis/dml_prediction_registry.dart';
import '../../../../common/analysis/dml_time_blocks.dart';
import '../../../../common/analysis/dml_timestamp.dart';
import '../../../../common/analysis/dml_treatment_context.dart';
import '../../../meal_analysis/domain/models/before_meal_context.dart';
import '../../../meal_analysis/domain/serialization/meal_carbohydrate_records_dml.dart';
import '../../../meal_analysis/domain/serialization/meal_comparison_evidence_dml.dart';
import '../../../meal_analysis/domain/serialization/meal_observation_dml.dart';
import '../../../meal_analysis/domain/serialization/meal_record_evidence_dml.dart';
import '../models/meal_advisor_context.dart';
import '../models/meal_advisor_input.dart';

MealAdvisorInput serializeMealAdvisorContext(
  MealAdvisorContext context, {
  required String requestId,
}) {
  final predictions = DmlPredictionRegistry();
  final before = context.before;
  final target = context.target;
  final ids = <String>{};
  final lines = <String>['DML/1'];
  void add(String id, Map<String, Object?> facts) {
    ids.add(id);
    lines.add('$id ${encodeDmlFacts(facts)}');
  }

  add('context', {
    'scope': 'before_meal_advisor',
    'request_id': requestId,
    'as_of': dmlTimestamp(before.asOf),
    'built_at': dmlTimestamp(context.builtAt),
    'failed_optional_sources': context.failures.toList(),
    'current_meal_is_planned': true,
    'export_decimal_places': 4,
    'history_source': 'current_history_reconstruction',
    'reading_order': [
      'planned_meal',
      'current_before',
      'current_cgm',
      'current_aaps',
      'current_insulin',
      'current_carbohydrate_records',
      'similar_meals',
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
  add(
    'current_before',
    beforeMealFactsDml(before, registerPrediction: predictions.register),
  );
  add('similar_meals', {
    'search_status': context.failures.contains('cancelled')
        ? 'cancelled'
        : context.target == null
        ? 'unavailable'
        : context.failures.contains('similar_search')
        ? 'failed'
        : context.similarMatchCount == null
        ? 'unknown'
        : 'complete',
    'matched_count': context.similarMatchCount,
    'included_count': context.comparisons.length,
    'maximum_included': 3,
    'selection_cutoff': dmlTimestamp(before.asOf),
  });
  add(
    'current_carbohydrate_records',
    mealCarbohydrateRecordsDml(
      treatments: before.treatments,
      start: before.asOf.subtract(before.windows.meals),
      end: before.asOf,
      includeNotes: false,
    ),
  );
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
      registerPrediction: predictions.register,
      includeNotes: false,
    ),
  );
  add(
    'current_insulin',
    dmlInsulinRecords(
      treatments: before.treatments,
      start: insulinStart,
      end: before.asOf,
    ),
  );
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
      ...mealComparisonEvidenceDml(
        current: before,
        reference: entry.$2.observation,
      ),
    });
    appendMealObservationDml(
      add,
      prefix,
      entry.$2.observation,
      predictions: predictions,
    );
  }
  for (final prediction in predictions.entries) {
    add(prediction.id, prediction.facts);
  }
  return MealAdvisorInput(
    context: context,
    requestId: requestId,
    text: lines.join('\n'),
    evidenceIds: ids,
  );
}
