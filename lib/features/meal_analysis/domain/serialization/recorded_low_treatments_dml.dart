import '../../../../common/analysis/dml_timestamp.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';

/// Preserve every saved entry. Equal timestamps/amounts do not prove identity.
List<Map<String, Object?>>? recordedLowTreatmentsDml(
  List<RecordedLowTreatment>? records,
) {
  if (records == null) return null;
  final counts = <(DateTime, double), int>{};
  for (final record in records) {
    final grams = record.netCarbsGrams;
    if (grams == null || !grams.isFinite || grams <= 0) continue;
    final key = (record.eatenAt.toUtc(), grams);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return [
    for (final record in records)
      {
        'at': dmlTimestamp(record.eatenAt),
        'net_carbs_g': record.netCarbsGrams?.isFinite == true
            ? record.netCarbsGrams
            : null,
        if ((counts[(record.eatenAt.toUtc(), record.netCarbsGrams)] ?? 0) > 1)
          'same_time_amount_records':
              counts[(record.eatenAt.toUtc(), record.netCarbsGrams)],
      },
  ];
}
