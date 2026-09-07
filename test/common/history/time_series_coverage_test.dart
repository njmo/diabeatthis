import 'package:diabeatthis/common/history/time_series_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 7, 12);
  final end = start.add(const Duration(hours: 1));

  test('offers download below 50 percent, but not at exactly 50 percent', () {
    for (final count in [0, 5, 6, 12]) {
      final coverage = TimeSeriesCoverage.fromTimestamps(
        timestamps: List.generate(
          count,
          (index) => start.add(Duration(minutes: index * 5)),
        ),
        start: start,
        end: end,
      );
      expect(coverage.expected, 12);
      expect(coverage.available, count);
      expect(coverage.isBelowHalf, count < 6);
    }
  });

  test('excludes duplicate timestamps and readings outside the range', () {
    final coverage = TimeSeriesCoverage.fromTimestamps(
      timestamps: [
        start,
        start,
        start.subtract(const Duration(minutes: 5)),
        end,
      ],
      start: start,
      end: end,
    );
    expect(coverage.available, 1);
    expect(coverage.isBelowHalf, isTrue);
  });

  test('counts only the elapsed analysis window and rounds up', () {
    final coverage = TimeSeriesCoverage.fromTimestamps(
      timestamps: [start],
      start: start,
      end: start.add(const Duration(minutes: 6)),
    );
    expect(coverage.expected, 2);
    expect(coverage.isBelowHalf, isFalse);
  });
}
