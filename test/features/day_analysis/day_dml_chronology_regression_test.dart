import 'dart:convert';

import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_dml_time_blocks.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_dml_timestamp.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_dml_window_facts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_dml_test.dart' show dmlFixture;
import 'day_timeline_dml_test.dart' show buildTimeline, timelineFixture;

void main() {
  test(
    'standalone and series use the same local clock without changing instant',
    () {
      final at = DateTime.utc(2026, 9, 8, 5, 3, 47);
      const offset = Duration(hours: 2);
      final encoded = dayDmlTimestamp(at, utcOffset: offset);
      final blocks = dayDmlTimeBlocks([
        (at: at, values: []),
      ], utcOffsetAt: (_) => offset)!;
      expect(encoded, '2026-09-08T07:03:47.000+02:00');
      expect(DateTime.parse(encoded), at);
      expect(blocks.single['date'], '2026-09-08');
      expect((blocks.single['rows'] as List).single, ['07:03']);
    },
  );

  test(
    'standalone time preserves midnight and distinct repeated DST instants',
    () {
      final midnight = DateTime.utc(2026, 9, 8, 22, 30);
      expect(
        dayDmlTimestamp(midnight, utcOffset: const Duration(hours: 2)),
        '2026-09-09T00:30:00.000+02:00',
      );
      final first = DateTime.utc(2026, 10, 25, 0, 30);
      final second = first.add(const Duration(hours: 1));
      final a = dayDmlTimestamp(first, utcOffset: const Duration(hours: 2));
      final b = dayDmlTimestamp(second, utcOffset: const Duration(hours: 1));
      expect(a, contains('02:30:00.000+02:00'));
      expect(b, contains('02:30:00.000+01:00'));
      expect(
        DateTime.parse(b).difference(DateTime.parse(a)),
        const Duration(hours: 1),
      );
    },
  );

  test(
    'window extrema expose chronology and do not turn post-meal low into baseline',
    () {
      final start = DateTime.utc(2026, 9, 10, 6);
      final readings = [
        for (final (minute, value) in [
          (0, 133),
          (5, 110),
          (10, 66),
          (15, 120),
          (20, 208),
        ])
          Glucose(
            externalId: null,
            source: GlucoseSource.cloud,
            date: start.add(Duration(minutes: minute)),
            sgv: value,
            direction: 'Flat',
          ),
      ];
      final facts = dayDmlWindowFacts(
        start: start,
        end: start.add(const Duration(minutes: 20)),
        glucose: GlucosePeriodSummary.calculate(
          readings,
          start,
          start.add(const Duration(minutes: 20)),
        ),
        basal: null,
        boluses: null,
      );
      expect(facts['min_mg_dl'], 66);
      final points = facts['chronological_points'] as List;
      expect(points.map((p) => p['mg_dl']), [133, 66, 208]);
      expect(
        DateTime.parse(points[1]['at'] as String),
        start.add(const Duration(minutes: 10)),
      );
      expect(
        DateTime.parse(points[2]['at'] as String),
        start.add(const Duration(minutes: 20)),
      );
      expect(points[2]['roles'], ['maximum', 'last_observed']);
      expect(facts['smb_u'], isNull);
    },
  );

  test('missing source differs from an empty observed window', () {
    final start = DateTime.utc(2026, 9, 10, 6);
    final end = start.add(const Duration(hours: 1));
    final missing = dayDmlWindowFacts(
      start: start,
      end: end,
      glucose: null,
      basal: null,
      boluses: null,
    );
    final empty = dayDmlWindowFacts(
      start: start,
      end: end,
      glucose: GlucosePeriodSummary.calculate([], start, end),
      basal: null,
      boluses: null,
    );
    expect(missing['chronological_points'], isNull);
    expect(empty['chronological_points'], isEmpty);
    expect(empty['min_mg_dl'], isNull);
    expect(empty['max_mg_dl'], isNull);
  });

  test('a stale last observation is not moved to the window end', () {
    final start = DateTime.utc(2026, 9, 10, 6);
    final end = start.add(const Duration(hours: 1));
    final reading = Glucose(
      externalId: null,
      source: GlucoseSource.cloud,
      date: start,
      sgv: 123,
      direction: 'Flat',
    );
    final facts = dayDmlWindowFacts(
      start: start,
      end: end,
      glucose: GlucosePeriodSummary.calculate([reading], start, end),
      basal: null,
      boluses: null,
    );
    final points = facts['chronological_points'] as List;
    expect(points, hasLength(1));
    expect(points.single['roles'], [
      'baseline',
      'minimum',
      'maximum',
      'last_observed',
    ]);
    expect(DateTime.parse(points.single['at'] as String), start);
    expect(DateTime.parse(facts['end'] as String), end);
    expect(facts['cgm_observed_min'], 5);
  });

  test(
    'meal workflow provenance accompanies durations without rewriting archived facts',
    () async {
      final accepted = dmlFixture();
      final archive = accepted.snapshot.encode();
      final doc = await buildTimeline(accepted, timelineFixture());
      final meal = doc.text
          .split('\n')
          .where((s) => s.startsWith('MEAL '))
          .map((s) => jsonDecode(s.substring(5)) as Map)
          .first;
      expect(meal['recorded_wait_min'], 10);
      expect(
        meal['timing_source'],
        'app_workflow_not_verified_delivery_or_consumption',
      );
      expect(accepted.snapshot.encode(), archive);
    },
  );

  test(
    'meal baseline timestamp preserves a nearer reading after eating started',
    () async {
      final start = DateTime.utc(2026, 10, 24, 19);
      final baselineAt = start.add(const Duration(minutes: 2, seconds: 10));
      final doc = await buildTimeline(
        dmlFixture(),
        timelineFixture(
          nightGlucose: [
            Glucose(
              externalId: null,
              source: GlucoseSource.cloud,
              date: start.subtract(const Duration(minutes: 4)),
              sgv: 240,
              direction: 'Flat',
            ),
            Glucose(
              externalId: null,
              source: GlucoseSource.cloud,
              date: baselineAt,
              sgv: 252,
              direction: 'Flat',
            ),
          ],
        ),
      );
      final meal = doc.text
          .split('\n')
          .where((s) => s.startsWith('MEAL '))
          .map((s) => jsonDecode(s.substring(5)) as Map)
          .singleWhere((m) => m['id'] == 'meal:1');
      final outcome = meal['outcome'] as Map;
      expect(DateTime.parse(meal['eaten_at'] as String), start);
      expect(DateTime.parse(outcome['start'] as String), start);
      expect(outcome['start_mg_dl'], 252);
      expect(DateTime.parse(outcome['start_at'] as String), baselineAt);
      expect(
        DateTime.parse(outcome['start_at'] as String).isAfter(start),
        isTrue,
      );
    },
  );
}
