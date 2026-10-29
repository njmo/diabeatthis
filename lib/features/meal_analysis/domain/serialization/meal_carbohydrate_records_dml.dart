import '../../../../common/analysis/dml_time_blocks.dart';
import '../../../../common/analysis/dml_timestamp.dart';
import '../../../../common/history/bolus_wizard_grouping.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../../core/domain/model/treatment_base.dart';

/// Export carbohydrate evidence separately from delivered insulin and local food.
/// A calculator amount is not a second intake when a matching record also exists.
Map<String, Object?> mealCarbohydrateRecordsDml({
  required List<Treatment>? treatments,
  required DateTime start,
  required DateTime end,
  bool includeNotes = true,
}) {
  bool calculatedByCutoff(BolusWizard wizard) {
    final at =
        wizard.calculatorResult?.timestamp ??
        wizard.calculatorResult?.dateCreated;
    return at == null || !at.isAfter(end);
  }

  final records = treatments
      ?.where(
        (t) =>
            t.isValid &&
            t.createdAt != null &&
            !t.createdAt!.isBefore(start) &&
            !t.createdAt!.isAfter(end) &&
            (t is! BolusWizard || calculatedByCutoff(t)),
      )
      .toList();
  final grouping = BolusWizardGrouping(records ?? []);
  return {
    'start': dmlTimestamp(start),
    'end': dmlTimestamp(end),
    'columns': ['time', 'record_kind', 'carbs_g', 'submission_relation'],
    'blocks': dmlTimeBlocks(
      records == null
          ? null
          : [
              for (final record in records)
                if (record is Treat && record.carbs > 0)
                  (
                    at: record.createdAt,
                    values: [
                      'recorded_carbs',
                      record.carbs,
                      grouping.isRelated(record)
                          ? 'calculator_submission_candidate'
                          : 'unassigned',
                    ],
                  )
                else if (record is BolusWizard &&
                    record.calculatorResult != null &&
                    record.carbs.isFinite &&
                    record.carbs > 0)
                  (
                    at: record.createdAt,
                    values: ['calculator_carbs', record.carbs, null],
                  ),
            ],
    ),
    if (includeNotes)
      'notes': [
        'Raw history records, not confirmed ingestion or a complete food diary.',
        'Calculator carbs describe a calculation. Matching carb records can describe the same submission; do not sum both.',
        'Local meals and rescues can describe these same events. No automatic cross-source identity or additional intake is implied.',
        'Unassigned means no submission match, not a diagnosed rescue or missing meal.',
      ],
  };
}
