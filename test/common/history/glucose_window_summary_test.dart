import 'package:diabeatthis/common/history/glucose_window_summary.dart';
import 'package:diabeatthis/common/history/latest_reading_at.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 8, 13);
  Glucose reading(int minute, int value) => Glucose(
    externalId: '$minute',
    source: GlucoseSource.cloud,
    date: start.add(Duration(minutes: minute)),
    sgv: value,
    direction: 'Flat',
  );
  GlucoseWindowSummary summarize(List<Glucose> values, {int minutes = 30}) =>
      GlucoseWindowSummary(
        readings: values,
        start: start,
        end: start.add(Duration(minutes: minutes)),
      );

  test(
    'end delta needs fresh readings at both ends and preserves its sign',
    () {
      expect(summarize([reading(0, 110), reading(30, 145)]).endDelta, 35);
      expect(summarize([reading(0, 145), reading(30, 110)]).endDelta, -35);
      expect(summarize([reading(0, 110), reading(30, 110)]).endDelta, 0);
      expect(summarize([reading(5, 110), reading(30, 145)]).endDelta, isNull);
      expect(summarize([reading(0, 110), reading(20, 145)]).endDelta, isNull);
    },
  );

  test('weights elapsed time, removes duplicates and leaves gaps unknown', () {
    final summary = summarize([
      reading(20, 60),
      reading(0, 100),
      reading(2, 200),
      reading(2, 200),
      reading(25, 120),
      reading(30, 110),
      reading(40, 300),
    ]);
    expect(summary.inRange, const Duration(minutes: 7));
    expect(summary.aboveRange, const Duration(minutes: 5));
    expect(summary.belowRange, const Duration(minutes: 5));
    expect(summary.missing, const Duration(minutes: 13));
    expect(summary.percent(summary.inRange), closeTo(7 / 17 * 100, 0.001));
    expect(summary.peak?.sgv, 200);
    expect(summary.last?.sgv, 110);
  });

  test('does not substitute post-meal or stale readings for baseline', () {
    expect(summarize([reading(-6, 100), reading(5, 150)]).baseline, isNull);
    expect(summarize([reading(-5, 110), reading(5, 150)]).baseline?.sgv, 110);
  });

  test('empty and zero-length windows have no percentages', () {
    final empty = summarize([]);
    expect(empty.percent(empty.inRange), isNull);
    expect(empty.missing, const Duration(minutes: 30));
    final zero = summarize([reading(0, 110)], minutes: 0);
    expect(zero.percent(zero.inRange), isNull);
    expect(zero.missing, Duration.zero);
  });

  test('records first observed in-range value after the highest reading', () {
    final summary = summarize([
      reading(0, 100),
      reading(5, 190),
      reading(10, 210),
      reading(15, 60),
      reading(20, 150),
      reading(25, 190),
    ]);
    expect(
      summary.firstReturnAfterPeak?.date,
      start.add(const Duration(minutes: 20)),
    );
    expect(
      summarize([reading(0, 100), reading(5, 170)]).firstReturnAfterPeak,
      isNull,
    );
    expect(
      summarize([reading(0, 200), reading(5, 210)]).firstReturnAfterPeak,
      isNull,
    );
  });

  test('selection never borrows a future or stale reading', () {
    final values = [reading(10, 150), reading(0, 100), reading(5, 120)];
    expect(
      latestReadingAt(
        values,
        start.add(const Duration(minutes: 7)),
        (g) => g.date,
      )?.sgv,
      120,
    );
    expect(
      latestReadingAt(
        values,
        start.add(const Duration(minutes: 16)),
        (g) => g.date,
      ),
      isNull,
    );
  });
}
