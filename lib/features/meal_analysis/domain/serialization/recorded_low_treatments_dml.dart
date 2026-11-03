import '../../../../common/analysis/dml_timestamp.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';

/// Preserve every saved entry. Equal timestamps/amounts do not prove identity.
List<Map<String, Object?>>? recordedLowTreatmentsDml(
  List<RecordedLowTreatment>? records,
) {
  if (records == null) return null;
  final counts = <(DateTime, double), int>{};
  for (final record in records) {
    final grams = record.historicalCarbs;
    if (grams == null || !grams.isFinite || grams <= 0) continue;
    final key = (record.eatenAt.toUtc(), grams);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return [
    for (final record in records)
      {
        'at': dmlTimestamp(record.eatenAt),
        if (!record.snapshotHistoryAvailable)
          'snapshot_history_available': false,
        if (!record.ingredientsAvailable) 'ingredient_amounts_available': false,
        if (record.historicalNutritionUnavailable) 'nutrition_available': false,
        'net_carbs_g': record.historicalCarbs?.isFinite == true
            ? record.historicalCarbs
            : null,
        if ((counts[(record.eatenAt.toUtc(), record.historicalCarbs)] ?? 0) > 1)
          'same_time_amount_records':
              counts[(record.eatenAt.toUtc(), record.historicalCarbs)],
      },
  ];
}
