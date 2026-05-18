import 'package:diabeatthis/foreground/collector/helpers/collector_next_reading_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const helper = CollectorNextReadingHelper();

  test('uses reading plus expected interval for fresh history seed', () {
    final readingDate = DateTime(2026, 5, 18, 10);
    final now = readingDate.add(const Duration(minutes: 4));

    expect(
      helper.nextExpectedAt(readingDate: readingDate, now: now),
      readingDate.add(CollectorNextReadingHelper.expectedInterval),
    );
  });

  test('uses next aligned window for stale history seed', () {
    final readingDate = DateTime(2026, 5, 18, 10);
    final now = readingDate.add(const Duration(minutes: 16));

    expect(
      helper.nextExpectedAt(readingDate: readingDate, now: now),
      readingDate.add(CollectorNextReadingHelper.expectedInterval * 4),
    );
  });
}
