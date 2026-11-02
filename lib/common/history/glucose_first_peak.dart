import '../../core/domain/model/glucose.dart';
import 'glucose_rise_summary.dart';

/// Retrospective local peak: a rise followed by two non-increasing lower
/// readings, allowing a plateau at the peak. Never bridges a missing interval.
class GlucoseFirstPeak {
  const GlucoseFirstPeak({this.peak, this.firstInRangeAfter});
  final Glucose? peak;
  final Glucose? firstInRangeAfter;

  factory GlucoseFirstPeak.fromReadings(List<Glucose> readings) {
    bool adjacent(int left, int right) {
      final gap = readings[right].date.difference(readings[left].date);
      return gap > Duration.zero && gap <= GlucoseRiseSummary.maximumGap;
    }

    for (var i = 1; i < readings.length - 2; i++) {
      if (!adjacent(i - 1, i) || readings[i].sgv <= readings[i - 1].sgv) {
        continue;
      }
      var after = i + 1;
      while (after < readings.length &&
          readings[after].sgv == readings[i].sgv &&
          adjacent(after - 1, after)) {
        after++;
      }
      if (after + 1 >= readings.length ||
          !adjacent(after - 1, after) ||
          !adjacent(after, after + 1) ||
          readings[after].sgv >= readings[i].sgv ||
          readings[after + 1].sgv > readings[after].sgv) {
        continue;
      }
      Glucose? returned;
      for (var j = i + 1; j < readings.length; j++) {
        if (!adjacent(j - 1, j)) break;
        if (readings[j].sgv >= 70 && readings[j].sgv <= 180) {
          returned = readings[j];
          break;
        }
      }
      return GlucoseFirstPeak(peak: readings[i], firstInRangeAfter: returned);
    }
    return const GlucoseFirstPeak();
  }
}
