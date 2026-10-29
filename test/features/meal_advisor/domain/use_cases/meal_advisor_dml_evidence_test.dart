import 'dart:convert';

import 'package:diabeatthis/common/analysis/dml_timestamp.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_context.dart';
import 'package:diabeatthis/features/meal_advisor/domain/serialization/meal_advisor_dml.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/build_meal_advisor_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_carbohydrate_records_dml.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/recorded_low_treatments_dml.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../common/analysis/dml_aaps_context_test.dart'
    show calculatorRecords, predicted;
import '../../../meal_analysis/build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros, reading;
import '../../../meal_analysis/meal_ai_test_fixtures.dart' show aiObservation;
import 'build_meal_advisor_context_test.dart'
    show plannedTarget, similarContext;

Map<String, dynamic> section(String text, String id) =>
    jsonDecode(
          text
              .split('\n')
              .firstWhere((l) => l.startsWith('$id '))
              .substring(id.length + 1),
        )
        as Map<String, dynamic>;
List<List<dynamic>> rows(Map<String, dynamic> section) =>
    (section['blocks'] as List)
        .expand((b) => (b as Map)['rows'] as List)
        .cast<List<dynamic>>()
        .toList();
void main() {
  test(
    'before-meal glucose and six-hour insulin totals have separate explicit windows',
    () async {
      final before = await builder(
        glucose: (_, _) async => [reading(-10), reading(-5), reading(0)],
        treatments: [
          ManualBolus(
            externalId: 'bolus',
            createdAt: cutoff.subtract(const Duration(hours: 2)),
            insulin: 1.75,
          ),
        ],
      )(asOf: cutoff, mealId: 1, macros: macros);
      final text = serializeMealAdvisorContext(
        MealAdvisorContext(
          before: before,
          target: plannedTarget(),
          builtAt: cutoff,
          comparisons: [],
          failures: {},
        ),
        requestId: 'test',
      ).text;
      final facts = section(text, 'current_before');
      final insulin = facts['insulin_window'] as Map;
      expect(
        facts['glucose_window']['start'],
        dmlTimestamp(cutoff.subtract(before.windows.glucose)),
      );
      expect(facts.containsKey('bolus_total_u'), false);
      expect(
        insulin['start'],
        dmlTimestamp(cutoff.subtract(before.windows.insulin)),
      );
      expect(insulin['end'], dmlTimestamp(cutoff));
      expect(insulin['bolus_total_u'], 1.75);
      expect(section(text, 'current_insulin')['start'], insulin['start']);
    },
  );
  test(
    'carbohydrate evidence keeps raw intake and calculator amounts distinct without deleting either',
    () {
      final at = cutoff.subtract(const Duration(hours: 1));
      final wizard = calculatorRecords(at).whereType<BolusWizard>().single;
      final data = mealCarbohydrateRecordsDml(
        treatments: [
          Treat(externalId: 'record', createdAt: at, carbs: 20),
          wizard.copyWith(
            calculatorResult: wizard.calculatorResult!.copyWith(carbs: 20),
          ),
          Treat(
            externalId: 'other',
            createdAt: at.subtract(const Duration(minutes: 15)),
            carbs: 10,
          ),
          Treat(
            externalId: 'future',
            createdAt: cutoff.add(const Duration(seconds: 1)),
            carbs: 30,
          ),
        ],
        start: cutoff.subtract(const Duration(hours: 6)),
        end: cutoff,
      );
      final events = rows(data);
      expect(events, hasLength(3));
      expect(events.where((r) => r[1] == 'calculator_carbs').single[2], 20);
      expect(
        events.where((r) => r[1] == 'recorded_carbs' && r[2] == 20).single[3],
        'calculator_submission_candidate',
      );
      expect(events.where((r) => r[2] == 10).single[3], 'unassigned');
      expect(data.containsKey('total_carbs_g'), false);
      expect(
        mealCarbohydrateRecordsDml(
          treatments: null,
          start: at,
          end: cutoff,
        )['blocks'],
        isNull,
      );
      expect(
        mealCarbohydrateRecordsDml(
          treatments: [],
          start: at,
          end: cutoff,
        )['blocks'],
        isEmpty,
      );
    },
  );
  test(
    'future calculator timestamps do not hide a raw carbohydrate entry as matched',
    () {
      final at = cutoff.subtract(const Duration(minutes: 1));
      final wizard = calculatorRecords(
        at,
        calculatedAt: cutoff.add(const Duration(minutes: 1)),
      ).whereType<BolusWizard>().single;
      final facts = mealCarbohydrateRecordsDml(
        treatments: [
          Treat(externalId: 'raw', createdAt: at, carbs: 20),
          wizard.copyWith(
            calculatorResult: wizard.calculatorResult!.copyWith(carbs: 20),
          ),
        ],
        start: cutoff.subtract(const Duration(hours: 1)),
        end: cutoff,
      );
      expect(rows(facts), hasLength(1));
      expect(rows(facts).single[3], 'unassigned');
    },
  );
  test(
    'same-time same-amount rescues are marked but every saved portion remains visible',
    () {
      final records = [
        for (var id = 1; id <= 3; id++)
          RecordedLowTreatment(
            mealId: id,
            eatenAt: cutoff,
            netCarbsGrams: 7.35,
          ),
        RecordedLowTreatment(
          mealId: 4,
          eatenAt: cutoff.add(const Duration(seconds: 14)),
          netCarbsGrams: 7.35,
        ),
      ];
      final facts = recordedLowTreatmentsDml(records)!;
      expect(facts, hasLength(4));
      expect(
        facts.take(3).every((r) => r['same_time_amount_records'] == 3),
        true,
      );
      expect(facts.last.containsKey('same_time_amount_records'), false);
      expect(records.map((r) => r.netCarbsGrams), everyElement(7.35));
      expect(recordedLowTreatmentsDml(null), isNull);
      expect(recordedLowTreatmentsDml([]), isEmpty);
    },
  );
  test(
    'runtime prediction is exported once without losing snapshot age or series',
    () async {
      final before = await builder(statuses: [predicted(cutoff)])(
        asOf: cutoff,
        mealId: 1,
        macros: macros,
      );
      final text = serializeMealAdvisorContext(
        MealAdvisorContext(
          before: before,
          target: plannedTarget(),
          builtAt: cutoff,
          comparisons: [],
          failures: {},
        ),
        requestId: 'test',
      ).text;
      expect(
        (section(text, 'current_before')['aaps'] as Map).containsKey(
          'prediction',
        ),
        false,
      );
      expect(section(text, 'current_before')['aaps']['prediction_age_min'], 0);
      expect(RegExp('"series"').allMatches(text), hasLength(1));
    },
  );
  test(
    'successful empty search and failed search have different explicit states',
    () async {
      final base = builder();
      final before = await BuildBeforeMealContextUseCase(
        loadGlucose: base.loadGlucose,
        loadDeviceStatuses: base.loadDeviceStatuses,
        loadTreatments: base.loadTreatments,
        loadMeals: base.loadMeals,
        loadLowTreatments: (_, _) async => [
          RecordedLowTreatment(mealId: 3, eatenAt: cutoff, netCarbsGrams: 7),
        ],
        loadActivities: base.loadActivities,
        loadPodAge: base.loadPodAge,
        now: base.now,
      )(asOf: cutoff, mealId: 1, macros: macros);
      for (final fail in [false, true]) {
        final context = await BuildMealAdvisorContextUseCase(
          now: () => cutoff,
          loadTarget: (_) async => plannedTarget(),
          findSimilar: (_, _) async {
            if (fail) throw StateError('Unavailable');
            return SimilarMealContext(
              asOf: cutoff,
              searchStart: cutoff.subtract(const Duration(days: 90)),
              target: macros,
              matches: [],
            );
          },
          loadHistorical: (_, _) => throw StateError('No matches'),
        )(before);
        final text = serializeMealAdvisorContext(
          context,
          requestId: 'test',
        ).text;
        expect(
          section(text, 'similar_meals')['search_status'],
          fail ? 'failed' : 'complete',
        );
        expect(
          section(text, 'similar_meals')['matched_count'],
          fail ? null : 0,
        );
        expect(section(text, 'similar_meals')['included_count'], 0);
        expect(
          section(text, 'current_before')['events']['rescues'],
          hasLength(1),
        );
      }
    },
  );
  test(
    'matching candidates and included completed references are counted separately',
    () async {
      final before = await builder()(asOf: cutoff, mealId: 1, macros: macros);
      final context = await BuildMealAdvisorContextUseCase(
        now: () => cutoff,
        loadTarget: (_) async => plannedTarget(),
        findSimilar: (_, _) async => similarContext(),
        loadHistorical: (id, _) async => aiObservation(
          id: id,
          time: cutoff.subtract(Duration(days: id)),
        ),
      )(before);
      final facts = section(
        serializeMealAdvisorContext(context, requestId: 'test').text,
        'similar_meals',
      );
      expect(facts['matched_count'], 5);
      expect(facts['included_count'], 3);
    },
  );
}
