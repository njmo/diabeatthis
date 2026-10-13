import '../../../../common/analysis/dml_time_blocks.dart';

typedef DayDmlTimedRow = DmlTimedRow;
List<Map<String, Object?>>? dayDmlTimeBlocks(
  Iterable<DayDmlTimedRow>? rows, {
  Duration Function(DateTime)? utcOffsetAt,
}) => dmlTimeBlocks(rows, utcOffsetAt: utcOffsetAt);
