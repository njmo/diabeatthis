/// A time interval for which the source cannot support reconstruction.
class HistoryCoverageGap {
  final DateTime start;
  final DateTime end;

  const HistoryCoverageGap({required this.start, required this.end});
}
