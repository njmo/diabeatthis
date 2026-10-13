import '../../../../common/analysis/dml_timestamp.dart';

String dayDmlTimestamp(DateTime instant, {Duration? utcOffset}) =>
    dmlTimestamp(instant, utcOffset: utcOffset);
String dayDmlUtcOffset(Duration offset) => dmlUtcOffset(offset);
