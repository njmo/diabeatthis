import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/features/day_analysis/data/prompts/day_analysis_prompt.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_history.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal_batch.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_result.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_dml_document.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_analysis_dml_serializer.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_analysis_context_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/load_day_analysis_history_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';
import 'day_analysis_api_test.dart' show analysisResponse;
import 'day_dml_test.dart' show dmlFixture, dmlSection;

DayAnalysisMeal timelineMeal(int id, DateTime at) => DayAnalysisMeal(
  id: id,
  name: 'Meal $id',
  eatenAt: at,
  eatingEndedAt: at.add(const Duration(minutes: 15)),
  wait: const Duration(minutes: 10),
  window: const Duration(hours: 3),
  macros: MealMacroSummary(
    carbsGrams: 30,
    fatGrams: 20,
    proteinGrams: 15,
    fiberGrams: 0,
    totalGrams: 150,
  ),
  macroSource: 'consumed',
  ingredients: [(name: 'Bread', grams: 30)],
  stages: [
    (status: 'bolused-waiting', at: at.subtract(const Duration(minutes: 10))),
    (status: 'eating', at: at),
  ],
);

DayAnalysisHistory timelineFixture({
  bool failed = false,
  List<DeviceStatus> statuses = const [],
  List<Glucose> nightGlucose = const [],
}) {
  final late = DateTime.utc(2026, 10, 25, 22, 30);
  return DayAnalysisHistory(
    start: DateTime.utc(2026, 10, 23, 20),
    end: DateTime.utc(2026, 10, 26, 2),
    builtAt: DateTime.utc(2026, 10, 26, 8),
    glucose: failed
        ? null
        : [
            ...nightGlucose,
            for (var i = 0; i <= 36; i++)
              Glucose(
                externalId: null,
                source: GlucoseSource.cloud,
                date: late.add(Duration(minutes: i * 5)),
                sgv: 100 + i * 3,
                direction: 'Flat',
              ),
            Glucose(
              externalId: null,
              source: GlucoseSource.cloud,
              date: late,
              type: GlucoseType.finger,
              sgv: 999,
              direction: 'Flat',
            ),
          ],
    statuses: failed ? null : statuses,
    treatments: failed
        ? null
        : [
            ExtendedCarb(
              externalId: 'private',
              createdAt: late.subtract(const Duration(hours: 1)),
              carbs: 40,
              duration: 4 * 60 * 60000,
            ),
            CorrectionBolus(
              externalId: 'private',
              createdAt: DateTime.utc(2026, 10, 25, 2),
              insulin: 0.1,
            ),
            CorrectionBolus(
              externalId: 'private',
              createdAt: late.add(const Duration(minutes: 60)),
              insulin: 0.2,
            ),
          ],
    meals: [
      timelineMeal(1, DateTime.utc(2026, 10, 24, 19)),
      timelineMeal(2, late),
      timelineMeal(3, late.add(const Duration(hours: 1))),
    ],
    lows: failed ? null : [],
    activities: failed ? null : [],
    failures: failed
        ? {'cgm', 'device_status', 'treatments', 'activities', 'low_treatments'}
        : {},
  );
}

void main() {
  test(
    'chronology includes lead-in, night SMB and a late meal beyond midnight',
    () async {
      final accepted = dmlFixture();
      final original = accepted.snapshot.encode();
      final doc = await buildTimeline(accepted, timelineFixture());
      final rows = doc.text
          .split('\n')
          .where((s) => s.startsWith('MEAL '))
          .map((s) => jsonDecode(s.substring(5)) as Map)
          .toList();
      expect(rows.length, 3);
      expect(rows.first['analyze'], false);
      expect(rows[1]['analyze'], true);
      expect(rows[2]['analyze'], false);
      expect(
        DateTime.parse(rows[1]['outcome']['expected_until'] as String),
        DateTime.utc(2026, 10, 26, 1, 30),
      );
      expect(
        (rows[1]['outcome']['other_meals_at'] as List).map(
          (at) => DateTime.parse(at as String),
        ),
        contains(DateTime.utc(2026, 10, 25, 23, 30)),
      );
      expect(
        rows[1]['before']['active_ecarbs'].first['scheduled_remaining_g'],
        30,
      );
      expect(rows[1]['outcome']['ecarbs_overlap'].first['scheduled_g'], 30);
      expect(rows[1]['outcome']['start_mg_dl'], 100);
      expect(doc.meals.keys, ['meal:2']);
      expect(
        dmlSection(doc.text, 'CGM')['blocks'].toString(),
        isNot(contains('999')),
      );
      expect(dmlSection(doc.text, 'NIGHT_COURSE')['smb_count'], 1);
      expect(
        (dmlSection(doc.text, 'BOLUSES')['blocks'] as List)
            .expand((block) => block['rows'] as List)
            .length,
        2,
      );
      expect(doc.text, isNot(contains('private')));
      expect(accepted.snapshot.encode(), original);
      expect(buildDayAnalysisPrompt(doc, 'pl'), contains('"meal:2":{"status"'));
      final response = analysisResponse();
      response['sections']['meal:2'] = response['sections']['meals'];
      expect(
        DayAnalysisResult.parse(
          jsonEncode(response),
          language: 'pl',
          evidenceIds: doc.evidenceIds,
          mealSectionIds: doc.meals.keys.toList(),
        ).sections,
        contains('meal:2'),
      );
      response['sections'].remove('meal:2');
      expect(
        () => DayAnalysisResult.parse(
          jsonEncode(response),
          language: 'pl',
          evidenceIds: doc.evidenceIds,
          mealSectionIds: doc.meals.keys.toList(),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'night intervals expose increased basal alongside SMB and the glucose course',
    () async {
      final start = DateTime.utc(2026, 10, 25, 2);
      final statuses = [
        for (var i = 0; i < 12; i++)
          testDeviceStatus(
            date: start.add(Duration(minutes: 5 * i)),
            iob: 0.5,
            cob: 0,
            tick: '',
            bg: 160 + i * 5,
            baseBasalRate: 0.6,
            tempBasalRemainingMinutes: 30,
          ).copyWith(
            basalObservedAt: start.add(Duration(minutes: 5 * i)),
            tempBasalAbsoluteRate: 1.2,
          ),
      ];
      final readings = [
        for (var i = 0; i < 12; i++)
          Glucose(
            externalId: null,
            source: GlucoseSource.cloud,
            date: start.add(Duration(minutes: 5 * i)),
            sgv: 160 + i * 5,
            direction: 'SingleUp',
          ),
      ];
      final doc = await buildTimeline(
        dmlFixture(),
        timelineFixture(statuses: statuses, nightGlucose: readings),
      );
      final interval =
          (dmlSection(doc.text, 'NIGHT_COURSE')['intervals'] as List)
              .singleWhere(
                (w) => DateTime.parse(w['start'] as String) == start,
              );
      expect(interval['basal_u'], closeTo(1.2, 0.0001));
      expect(interval['basal_profile_u'], closeTo(0.6, 0.0001));
      expect(interval['basal_added_u'], closeTo(0.6, 0.0001));
      expect(interval['smb_count'], 1);
      final intervals =
          dmlSection(doc.text, 'NIGHT_COURSE')['intervals'] as List;
      expect(
        intervals.fold<int>(0, (sum, w) => sum + (w['smb_count'] as int)),
        1,
      );
      expect(interval['max_mg_dl'], 215);
      expect(interval['basal_coverage'], 1);
    },
  );

  test(
    'missing history remains unknown, not zero delivery or an empty observed course',
    () async {
      final doc = await buildTimeline(
        dmlFixture(),
        timelineFixture(failed: true),
      );
      expect(dmlSection(doc.text, 'CGM')['blocks'], isNull);
      expect(dmlSection(doc.text, 'BOLUSES')['blocks'], isNull);
      expect(dmlSection(doc.text, 'NIGHT_COURSE')['smb_count'], isNull);
      expect(dmlSection(doc.text, 'NIGHT_COURSE')['basal_u'], isNull);
      expect(
        dmlSection(doc.text, 'HISTORY')['failed_sources'],
        contains('cgm'),
      );
    },
  );

  test(
    'history sources start concurrently and are fetched once with archived day boundaries',
    () async {
      final pending = Completer<void>();
      final calls = <String>[];
      Future<T> read<T>(String name, T value) async {
        calls.add(name);
        await pending.future;
        return value;
      }

      final useCase = LoadDayAnalysisHistoryUseCase(
        now: () => DateTime.utc(2026, 10, 26, 8),
        loadGlucose: (s, e) => read('cgm', []),
        loadStatuses: (s, e) => read('pump', []),
        loadTreatments: (s, e) => read('treatments', []),
        loadMeals: (s, e) => read('meals', DayAnalysisMealBatch(meals: [])),
        loadLows: (s, e) => read('lows', []),
        loadActivities: (s, e) => read('activities', []),
      );
      final result = useCase(dmlFixture());
      expect(calls.toSet(), {
        'cgm',
        'pump',
        'treatments',
        'meals',
        'lows',
        'activities',
      });
      expect(calls.length, 6);
      pending.complete();
      final history = await result;
      expect(history.start, DateTime.utc(2026, 10, 23, 20));
      expect(history.end, DateTime.utc(2026, 10, 26, 2));
      expect(history.failures, isEmpty);
    },
  );
}

Future<DayDmlDocument> buildTimeline(
  AcceptedDaySummary accepted,
  DayAnalysisHistory history,
) async => serializeDayAnalysisContext(
  await const BuildDayAnalysisContextUseCase()(accepted, history),
);
