import 'package:diabeatthis/common/history/history_coverage_gap.dart';
import 'package:diabeatthis/common/history/insulin_basal_summary.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/device_status_factory.dart';

final start = DateTime(2026, 9, 10, 12);
DeviceStatus snapshot(
  int minute, {
  double? rate,
  int remaining = 0,
  double profile = 0.6,
}) {
  final at = start.add(Duration(minutes: minute));
  return testDeviceStatus(
    date: at,
    iob: 0,
    cob: 0,
    tick: '',
    bg: 120,
    baseBasalRate: profile,
    tempBasalRemainingMinutes: remaining,
  ).copyWith(basalObservedAt: at, tempBasalAbsoluteRate: rate);
}

InsulinBasalSummary calculate(List<DeviceStatus> records, [int minutes = 20]) =>
    InsulinBasalSummary.calculate(
      records,
      start,
      start.add(Duration(minutes: minutes)),
    );

void main() {
  test('late uploads cannot alter a context built at an earlier cutoff', () {
    final late = snapshot(
      0,
    ).copyWith(date: start.add(const Duration(minutes: 30)));
    expect(calculate([late], 10).coverage, 0);
    expect(calculate([late], 30).coveredDuration, const Duration(minutes: 10));
  });
  test('empty windows and reversed bounds are handled explicitly', () {
    final empty = calculate([snapshot(0)], 0);
    expect(empty.coverage, 0);
    expect(empty.gaps, isEmpty);
    expect(() => calculate([], -1), throwsArgumentError);
  });
  test('gap collections are immutable snapshots', () {
    final gaps = <HistoryCoverageGap>[];
    final summary = InsulinBasalSummary(
      units: 0,
      profileUnits: 0,
      addedUnits: 0,
      reducedUnits: 0,
      coveredDuration: Duration.zero,
      duration: const Duration(minutes: 5),
      gaps: gaps,
    );
    gaps.add(
      HistoryCoverageGap(
        start: start,
        end: start.add(const Duration(minutes: 5)),
      ),
    );
    expect(summary.gaps, isEmpty);
    expect(() => summary.gaps.add(gaps.single), throwsUnsupportedError);
  });
  test(
    'integrates rates and differences, superseding a thirty minute command',
    () {
      final result = calculate([
        snapshot(10, rate: 0.3, remaining: 30),
        snapshot(0, rate: 1.2, remaining: 30),
      ]);
      expect(result.units, closeTo(0.25, 1e-9));
      expect(result.profileUnits, closeTo(0.2, 1e-9));
      expect(result.addedUnits, closeTo(0.1, 1e-9));
      expect(result.reducedUnits, closeTo(0.05, 1e-9));
      expect(result.coverage, 1);
      expect(result.gaps, isEmpty);
    },
  );
  test('does not extend coverage for repeats or bridge gaps', () {
    final first = snapshot(0);
    final result = calculate([
      first,
      first.copyWith(date: start.add(const Duration(minutes: 8))),
      snapshot(25),
    ], 30);
    expect(result.coveredDuration, const Duration(minutes: 15));
    expect(result.units, closeTo(0.15, 1e-9));
    expect(result.gaps.single.start, start.add(const Duration(minutes: 10)));
    expect(result.gaps.single.end, start.add(const Duration(minutes: 25)));
  });
  test(
    'clips observations at window boundaries and excludes future reports',
    () {
      final result = calculate([
        snapshot(-5),
        snapshot(5),
        snapshot(15),
        snapshot(25),
      ]);
      expect(result.units, closeTo(0.2, 1e-9));
      expect(result.coverage, 1);
    },
  );
  test('stops at expiry until another pump snapshot confirms the profile', () {
    final result = calculate([
      snapshot(0, rate: 1.2, remaining: 3),
      snapshot(5),
    ], 10);
    expect(result.units, closeTo(0.11, 1e-9));
    expect(result.coveredDuration, const Duration(minutes: 8));
  });
  test('missing temporary rate is unknown, explicit zero is valid', () {
    expect(calculate([snapshot(0, remaining: 30)], 5).coverage, 0);
    final zero = calculate([snapshot(0, rate: 0, remaining: 30)], 5);
    expect(zero.coverage, 1);
    expect(zero.units, 0);
    expect(zero.reducedUnits, closeTo(0.05, 1e-9));
  });
  test('AAPS omits zero rate and ongoing statuses need no enacted command', () {
    final zero = snapshot(0, remaining: 30).copyWith(
      tempBasalStartedAt: DateFormat('dd.MM.yyyy HH:mm').format(start),
    );
    final continued = snapshot(
      5,
      remaining: 25,
    ).copyWith(tempBasalStartedAt: zero.tempBasalStartedAt);
    final result = calculate([zero, continued], 10);
    expect(result.coverage, 1);
    expect(result.units, 0);
    expect(result.reducedUnits, closeTo(0.1, 1e-9));
    expect(
      calculate([zero.copyWith(enactedBasalReceived: false)], 5).coverage,
      1,
    );
    expect(
      calculate([
        zero.copyWith(
          enactedBasalAt: start.subtract(const Duration(minutes: 30)),
        ),
      ], 5).coverage,
      1,
    );
    expect(calculate([zero.copyWith(tempBasalStartedAt: ' ')], 5).coverage, 0);
  });
  test(
    'legacy, malformed and ambiguous records do not imply zero or profile',
    () {
      for (final record in [
        snapshot(0).copyWith(basalObservedAt: null),
        snapshot(0, profile: double.nan),
        snapshot(0, rate: -1, remaining: 30),
        snapshot(0).copyWith(tempBasalStartedAt: '10.09.2026 12:00'),
        snapshot(
          0,
        ).copyWith(basalObservedAt: start.add(const Duration(minutes: 5))),
      ]) {
        expect(calculate([record], 5).coverage, 0);
      }
      expect(
        calculate([], 5).gaps.single.end,
        start.add(const Duration(minutes: 5)),
      );
    },
  );
  test('profile changes are integrated per snapshot', () {
    final result = calculate([snapshot(0), snapshot(10, profile: 1.2)]);
    expect(result.profileUnits, closeTo(0.3, 1e-9));
    expect(result.units, closeTo(0.3, 1e-9));
  });
}
