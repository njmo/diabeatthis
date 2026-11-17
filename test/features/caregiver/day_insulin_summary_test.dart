import 'package:diabeatthis/common/history/insulin_basal_summary.dart';
import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/common/presentation/day/day_insulin_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const zeroBoluses = InsulinBolusSummary(
    manualCount: 0,
    manualUnits: 0,
    otherCount: 0,
    otherUnits: 0,
  );
  InsulinBasalSummary basal(int covered, {double units = 0}) =>
      InsulinBasalSummary(
        units: units,
        profileUnits: 0,
        addedUnits: 0,
        reducedUnits: 0,
        coveredDuration: Duration(minutes: covered),
        duration: const Duration(hours: 1),
        gaps: [],
      );

  test('missing sources and unobserved basal cannot produce a total', () {
    for (final data in [
      const DayInsulinSummary(boluses: null, basal: null),
      const DayInsulinSummary(boluses: zeroBoluses, basal: null),
      DayInsulinSummary(boluses: null, basal: basal(60, units: 1)),
      DayInsulinSummary(boluses: zeroBoluses, basal: basal(0)),
    ]) {
      expect(data.totalUnits, isNull);
    }
  });

  test('observed zero stays zero, and partial coverage stays explicit', () {
    final zero = DayInsulinSummary(boluses: zeroBoluses, basal: basal(60));
    expect(zero.totalUnits, 0);
    expect(zero.isPartial, isFalse);
    final partial = DayInsulinSummary(
      boluses: zeroBoluses,
      basal: basal(30, units: 0.5),
    );
    expect(partial.totalUnits, 0.5);
    expect(partial.isPartial, isTrue);
  });
}
