import 'package:diabeatthis/features/day_analysis/domain/serialization/day_dml_time_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local midnight starts another block without dropping readings', () {
    final first = DateTime.utc(2026, 9, 14, 21, 55, 37);
    final second = DateTime.utc(2026, 9, 14, 22, 0, 12);
    final result = dayDmlTimeBlocks([
      (at: second, values: [164]),
      (at: first, values: [157]),
    ], utcOffsetAt: (_) => const Duration(hours: 2))!;
    expect(result, [
      {
        'date': '2026-09-14',
        'utc_offset': '+02:00',
        'rows': [
          ['23:55', 157],
        ],
      },
      {
        'date': '2026-09-15',
        'utc_offset': '+02:00',
        'rows': [
          ['00:00', 164],
        ],
      },
    ]);
    expect(first.second, 37);
    expect(second.second, 12);
  });

  test(
    'DST repeated hour is unambiguous and cross-block end keeps its offset',
    () {
      final first = DateTime.utc(2026, 10, 25, 0, 30);
      final second = DateTime.utc(2026, 10, 25, 1, 30);
      final result = dayDmlTimeBlocks(
        [
          (at: first, values: [second]),
          (at: second, values: [null]),
        ],
        utcOffsetAt: (at) =>
            Duration(hours: at.isBefore(DateTime.utc(2026, 10, 25, 1)) ? 2 : 1),
      )!;
      expect(result.first['utc_offset'], '+02:00');
      expect(result.last['utc_offset'], '+01:00');
      expect(result.first['rows'], [
        ['02:30', '2026-10-25T02:30+01:00'],
      ]);
      expect(result.last['rows'], [
        ['02:30', null],
      ]);
    },
  );

  test('same minute events remain distinct, sorted by exact time', () {
    final at = DateTime.utc(2026, 9, 15, 8);
    final result = dayDmlTimeBlocks([
      (at: at.add(const Duration(seconds: 50)), values: [0.2]),
      (at: at.add(const Duration(seconds: 10)), values: [0.1]),
    ], utcOffsetAt: (_) => Duration.zero)!;
    expect(result.single['rows'], [
      ['08:00', 0.1],
      ['08:00', 0.2],
    ]);
  });

  test(
    'secondary times crossing midnight retain date and fractional offset',
    () {
      final at = DateTime.utc(2026, 9, 15, 3, 20);
      final result = dayDmlTimeBlocks([
        (at: at, values: [at.add(const Duration(minutes: 20)), at]),
      ], utcOffsetAt: (_) => const Duration(hours: -3, minutes: -30))!;
      expect(result.single['date'], '2026-09-14');
      expect(result.single['utc_offset'], '-03:30');
      expect(result.single['rows'], [
        ['23:50', '2026-09-15T00:10-03:30', '23:50'],
      ]);
    },
  );

  test('unavailable and empty series stay distinct', () {
    expect(dayDmlTimeBlocks(null), isNull);
    expect(dayDmlTimeBlocks([]), isEmpty);
  });
}
