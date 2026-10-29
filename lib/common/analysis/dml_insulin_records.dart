import '../../core/domain/model/correction_bolus.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treatment_base.dart';
import 'dml_time_blocks.dart';
import 'dml_timestamp.dart';

/// Recorded delivery entries only. Calculator recommendations are never deliveries.
Map<String, Object?> dmlInsulinRecords({
  required List<Treatment>? treatments,
  required DateTime start,
  required DateTime end,
}) => {
  'start': dmlTimestamp(start),
  'end': dmlTimestamp(end),
  'columns': ['time', 'kind', 'units'],
  'blocks': dmlTimeBlocks(
    treatments == null
        ? null
        : [
            for (final record in treatments)
              if (record.isValid &&
                  record.createdAt != null &&
                  !record.createdAt!.isBefore(start) &&
                  !record.createdAt!.isAfter(end))
                if (record is ManualBolus &&
                    record.insulin.isFinite &&
                    record.insulin > 0)
                  (at: record.createdAt, values: ['manual', record.insulin])
                else if (record is CorrectionBolus &&
                    record.insulin.isFinite &&
                    record.insulin > 0)
                  (at: record.createdAt, values: ['smb', record.insulin]),
          ],
  ),
};
