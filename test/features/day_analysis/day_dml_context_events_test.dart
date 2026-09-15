import 'dart:convert';

import 'package:diabeatthis/core/domain/model/bg_check.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/stress_event.dart';
import 'package:diabeatthis/core/domain/model/stress_event_treatment.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/day_analysis/data/prompts/day_analysis_prompt.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_history.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_analysis_dml_serializer.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_dml_treatment_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_analysis_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_dml_test.dart' show dmlFixture, dmlSection;

void main() {
  final start = DateTime.utc(2026, 10, 25, 12);
  final end = start.add(const Duration(hours: 4));
  DayAnalysisHistory history({
    List<Treatment>? treatments = const [],
    List<Glucose>? glucose = const [],
  }) => DayAnalysisHistory(
    start: start.subtract(const Duration(days: 1)),
    end: end,
    builtAt: end,
    treatments: treatments,
    glucose: glucose,
    statuses: [],
    meals: [],
    lows: [],
    activities: [],
    failures: {},
  );
  Map<String, Object?> section(DayAnalysisHistory h, String name) =>
      dayDmlTreatmentContext(h, start).singleWhere((s) => s.kind == name).facts;
  List<dynamic> rows(Map<String, Object?> section) =>
      (section['blocks'] as List)
          .expand((b) => (b as Map)['rows'] as List)
          .toList();
  StressEventTreatment stress(DateTime at, DateTime? until, {String? notes}) =>
      StressEventTreatment(
        StressEvent(
          id: 321,
          externalId: 'private-id',
          occurredAt: at,
          endedAt: until,
          stressLevel: StressLevel.high,
          source: 'manual',
          notes: notes,
        ),
      );
  TemporaryTarget target(DateTime at, int duration, {bool valid = true}) =>
      TemporaryTarget(
        nightscoutId: 'private-target',
        createdAt: at,
        durationInMiliseconds: duration * 60000,
        duration: duration,
        targetBottom: duration == 0 ? 0 : 140,
        targetTop: duration == 0 ? 0 : 150,
        isValid: valid,
      );

  test(
    'stress includes overlapping intervals and point entries without inventing duration',
    () {
      const notes = 'Exam\n"note"';
      final h = history(
        treatments: [
          stress(
            start.subtract(const Duration(hours: 1)),
            start.add(const Duration(minutes: 20)),
            notes: notes,
          ),
          stress(start.add(const Duration(hours: 1)), null),
          stress(start.subtract(const Duration(hours: 2)), null),
          stress(start.subtract(const Duration(hours: 2)), start),
          stress(end.add(const Duration(minutes: 1)), null),
        ],
      );
      final encoded = section(h, 'STRESS_EVENTS');
      final values = rows(encoded);
      expect(values, hasLength(2));
      expect(values.first.sublist(2), ['high', 'manual', notes]);
      expect(values.last[1], isNull);
      expect(jsonEncode(encoded), isNot(contains('private-id')));
      expect(jsonDecode(jsonEncode(encoded)), isNotEmpty);
    },
  );

  test(
    'temporary targets retain cancellation and replacement requests without counting insulin',
    () {
      final values = rows(
        section(
          history(
            treatments: [
              target(start.subtract(const Duration(minutes: 30)), 60),
              target(start.subtract(const Duration(minutes: 10)), 0),
              target(start.add(const Duration(minutes: 10)), 90),
              target(start.add(const Duration(minutes: 15)), 0),
              target(start, 120, valid: false),
              target(end.add(const Duration(minutes: 1)), 60),
            ],
          ),
          'TEMP_TARGETS',
        ),
      );
      expect(values.map((row) => row[1]), [60, 0, 90, 0]);
      expect(values.last.sublist(2), [0, 0]);
    },
  );

  test(
    'spot checks are deduplicated across sources and excluded from CGM',
    () async {
      final reading = Glucose(
        externalId: 'private-check',
        source: GlucoseSource.cloud,
        date: start,
        sgv: 123,
        direction: '',
        type: GlucoseType.finger,
        notes: 'Meter',
      );
      final cgm = reading.copyWith(type: GlucoseType.cgm, sgv: 110);
      final h = history(
        glucose: [reading, cgm],
        treatments: [BgCheck(reading)],
      );
      final document = serializeDayAnalysisContext(
        await const BuildDayAnalysisContextUseCase()(dmlFixture(), h),
      );
      final checks = rows(dmlSection(document.text, 'BG_CHECKS'));
      expect(checks, hasLength(1));
      expect(checks.single.sublist(1), [123, 'finger', 'cloud', 'Meter']);
      final cgmRows = rows(dmlSection(document.text, 'CGM'));
      expect(cgmRows.single[1], 110);
      expect(
        document.evidenceIds,
        containsAll(['stress_events', 'temp_targets', 'bg_checks']),
      );
      expect(document.text, isNot(contains('private-check')));
      final prompt = buildDayAnalysisPrompt(document, 'pl');
      expect(prompt, contains('Duration 0 cancels'));
      expect(prompt, contains('NOT that stress continued indefinitely'));
    },
  );

  test('incomplete or inverted positive-duration targets remain unknown', () {
    for (final bounds in [(0, 0), (0, 150), (140, 0), (-10, 150), (160, 140)]) {
      final request = target(
        start,
        60,
      ).copyWith(targetBottom: bounds.$1, targetTop: bounds.$2);
      final value = rows(
        section(history(treatments: [request]), 'TEMP_TARGETS'),
      ).single;
      expect(value.sublist(1), [60, null, null]);
    }
    final valid = target(start, 60).copyWith(targetBottom: 140, targetTop: 140);
    expect(
      rows(
        section(history(treatments: [valid]), 'TEMP_TARGETS'),
      ).single.sublist(1),
      [60, 140, 140],
    );
  });

  for (final blank in <String?>[null, '', '   ']) {
    test(
      'duplicate check with blank note ($blank) preserves recorded context',
      () {
        final reading = Glucose(
          externalId: 'check',
          source: GlucoseSource.cloud,
          date: start,
          sgv: 123,
          direction: '',
          type: GlucoseType.finger,
          notes: 'Before meal',
        );
        final values = rows(
          section(
            history(
              glucose: [reading],
              treatments: [
                BgCheck(reading.copyWith(date: start.toLocal(), notes: blank)),
              ],
            ),
            'BG_CHECKS',
          ),
        );
        expect(values, hasLength(1));
        expect(values.single.last, 'Before meal');
      },
    );
  }

  test(
    'distinct notes on duplicate checks are retained once without merging different readings',
    () {
      final reading = Glucose(
        externalId: 'check',
        source: GlucoseSource.cloud,
        date: start,
        sgv: 123,
        direction: '',
        type: GlucoseType.finger,
        notes: 'First line\nSecond line',
      );
      final values = rows(
        section(
          history(
            glucose: [reading],
            treatments: [
              BgCheck(reading.copyWith(notes: ' Meter confirmation ')),
              BgCheck(reading.copyWith(notes: 'Meter confirmation')),
              BgCheck(reading.copyWith(sgv: 124, notes: 'Different value')),
            ],
          ),
          'BG_CHECKS',
        ),
      );
      expect(values, hasLength(2));
      expect(values.first.last, 'First line\nSecond line\nMeter confirmation');
      expect(values.last.last, 'Different value');
    },
  );

  test(
    'unavailable context is distinct from no events; partial checks disclose missing source',
    () {
      final missing = history(treatments: null, glucose: null);
      for (final name in ['STRESS_EVENTS', 'TEMP_TARGETS', 'BG_CHECKS']) {
        expect(section(missing, name)['blocks'], isNull);
        expect(section(history(), name)['blocks'], isEmpty);
      }
      final partial = section(history(treatments: null), 'BG_CHECKS');
      expect(partial['failed_sources'], ['treatments']);
      expect(partial['blocks'], isEmpty);
    },
  );
}
