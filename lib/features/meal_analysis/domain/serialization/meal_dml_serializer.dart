import 'dart:convert';
import '../../../../common/analysis/dml_timestamp.dart';
import '../models/meal_ai_context.dart';
import '../models/meal_dml_document.dart';
import 'meal_observation_dml.dart';

num? _finite(num? value) => value != null && value.isFinite ? value : null;

/// Event-time evidence, not a reconstruction of what had reached the phone then.
MealDmlDocument serializeMealDml(MealAiContext context) {
  final ids = <String>{};
  final lines = <String>['DML/1'];
  void add(String id, Map<String, Object?> facts) {
    ids.add(id);
    lines.add('$id ${jsonEncode(facts)}');
  }

  add('context', {
    'scope': 'historical_meal',
    'built_at': dmlTimestamp(context.builtAt),
    'clock': 'device_timezone_at_generation',
    'failed_optional_sources': context.failures.toList(),
    'notes': [
      'History may contain later edits; it is not an audit of information available at meal time.',
      'eCarbs quantities describe scheduled release, not measured absorption.',
      'SMB is included in bolus totals. CGM gaps do not imply stable glucose.',
    ],
  });

  appendMealObservationDml(add, 'meal', context.current);
  for (final entry in context.comparisons.indexed) {
    final prefix = 'similar_${entry.$1 + 1}';
    add('${prefix}_match', {
      'same_ingredients': entry.$2.match.matchesIngredients,
      'portion_ratio': _finite(entry.$2.match.portionRatio),
      'macro_distance': _finite(entry.$2.match.distance),
    });
    appendMealObservationDml(add, prefix, entry.$2.observation);
  }
  return MealDmlDocument(
    mealId: context.current.meal.mealId,
    text: lines.join('\n'),
    evidenceIds: ids,
  );
}
