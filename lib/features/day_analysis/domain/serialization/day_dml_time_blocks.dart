import 'day_dml_timestamp.dart';

/// Values may include secondary timestamps (for example an activity end).
typedef DayDmlTimedRow = ({DateTime at, List<Object?> values});

/// Minute precision is presentation only: rows are sorted by their exact instant,
/// never deduplicated or averaged. Dates and UTC offsets belong to each block.
List<Map<String, Object?>>? dayDmlTimeBlocks(
  Iterable<DayDmlTimedRow>? rows, {
  Duration Function(DateTime)? utcOffsetAt,
}) {
  if (rows == null) return null;
  Duration offsetAt(DateTime at) =>
      utcOffsetAt?.call(at) ?? at.toLocal().timeZoneOffset;
  DateTime wallTime(DateTime at) => at.toUtc().add(offsetAt(at));
  String date(DateTime at) => wallTime(at).toIso8601String().substring(0, 10);
  String time(DateTime at) => wallTime(at).toIso8601String().substring(11, 16);
  String offset(DateTime at) => dayDmlUtcOffset(offsetAt(at));

  final ordered = rows.indexed.toList()
    ..sort((a, b) {
      final order = a.$2.at.compareTo(b.$2.at);
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
  final blocks = <Map<String, Object?>>[];
  String? lastDate;
  String? lastOffset;
  var values = <List<Object?>>[];
  for (final (_, row) in ordered) {
    final rowDate = date(row.at);
    final rowOffset = offset(row.at);
    if (rowDate != lastDate || rowOffset != lastOffset) {
      values = [];
      blocks.add({'date': rowDate, 'utc_offset': rowOffset, 'rows': values});
      lastDate = rowDate;
      lastOffset = rowOffset;
    }
    Object? encode(Object? value) {
      if (value is! DateTime) return value;
      if (date(value) == rowDate && offset(value) == rowOffset) {
        return time(value);
      }
      // An end or observation timestamp may cross midnight or a DST change.
      return '${date(value)}T${time(value)}${offset(value)}';
    }

    values.add([time(row.at), ...row.values.map(encode)]);
  }
  return blocks;
}
