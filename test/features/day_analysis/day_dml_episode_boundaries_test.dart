import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/data/prompts/day_analysis_prompt.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_history.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_analysis_dml_serializer.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_analysis_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/dml_sections.dart';
import 'day_dml_test.dart' show dmlFixture;

void main() {
  test(
    'day DML distinguishes waiting, eating, outcome and later peaks',
    () async {
      final at = DateTime.utc(2026, 10, 25, 9, 14);
      Glucose sample(int minute, int value) => Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: at.add(Duration(minutes: minute)),
        sgv: value,
        direction: 'Flat',
      );
      final accepted = dmlFixture();
      final document = serializeDayAnalysisContext(
        await const BuildDayAnalysisContextUseCase()(
          accepted,
          DayAnalysisHistory(
            start: at.subtract(const Duration(days: 1)),
            end: accepted.snapshot.asOf,
            builtAt: accepted.acceptedAt,
            glucose: [
              sample(0, 120),
              sample(30, 160),
              sample(60, 180),
              sample(95, 267),
            ],
            statuses: [],
            treatments: [],
            lows: [],
            activities: [],
            failures: {},
            meals: [
              DayAnalysisMeal(
                id: 1,
                name: 'Breakfast',
                eatenAt: at,
                eatingEndedAt: at.add(const Duration(minutes: 8)),
                wait: const Duration(minutes: 14),
                window: const Duration(minutes: 90),
                macros: null,
                macroSource: 'unknown',
                ingredients: [],
                stages: [
                  (
                    status: 'bolused-waiting',
                    at: at.subtract(const Duration(minutes: 14)),
                  ),
                  (status: 'eating', at: at),
                  (status: 'eaten', at: at.add(const Duration(minutes: 8))),
                ],
              ),
            ],
          ),
        ),
      );
      final meal = dmlFactsById(document.text, document.meals.keys.single);
      final timing = meal['recorded_timing'] as Map;
      expect(
        DateTime.parse(timing['waiting_started_at'] as String),
        at.subtract(const Duration(minutes: 14)),
      );
      expect(DateTime.parse(timing['eating_started_at'] as String), at);
      final outcome = meal['outcome'] as Map;
      expect(outcome['complete_window'], isTrue);
      expect(outcome['cgm_sampling_complete'], isFalse);
      expect(outcome['has_cgm_observations'], isTrue);
      expect(outcome['max_mg_dl'], 180);
      expect(
        DateTime.parse(outcome['end'] as String),
        at.add(const Duration(minutes: 90)),
      );
      expect(document.text, contains('267'));
      final prompt = buildDayAnalysisPrompt(document, 'pl');
      expect(
        prompt,
        contains('Allowed evidence IDs: ${document.evidenceIds.join(', ')}.'),
      );
    },
  );
}
