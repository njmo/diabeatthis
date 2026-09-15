import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_history_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal_batch.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/load_day_analysis_history_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/controllers/day_analysis_input_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_dml_test.dart' show dmlFixture;

void main() {
  test(
    'prepared input remains unchanged even when a source was unavailable',
    () async {
      final date = DateTime(2026, 10, 25);
      var glucoseReads = 0;
      final reads = <String, int>{};
      Future<T> success<T>(String source, T value) async {
        reads.update(source, (v) => v + 1, ifAbsent: () => 1);
        return value;
      }

      final loader = LoadDayAnalysisHistoryUseCase(
        now: () => DateTime.utc(2026, 10, 26, 8),
        loadGlucose: (s, e) async {
          if (++glucoseReads == 1) throw StateError('offline');
          return [];
        },
        loadStatuses: (s, e) => success('statuses', []),
        loadTreatments: (s, e) => success('treatments', []),
        loadMeals: (s, e) => success('meals', DayAnalysisMealBatch(meals: [])),
        loadLows: (s, e) => success('lows', []),
        loadActivities: (s, e) => success('activities', []),
      );
      final container = ProviderContainer(
        overrides: [
          acceptedDaySummaryProvider(
            date,
          ).overrideWith((ref) async => dmlFixture()),
          loadDayAnalysisHistoryProvider.overrideWithValue(loader),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(dayDmlProvider(date), (_, _) {});
      addTearDown(subscription.close);
      final first = await container.read(dayDmlProvider(date).future);
      expect(first!.text, contains('"failed_sources":["cgm"]'));
      expect(first.text, contains('"blocks":null'));
      await container.read(dayDmlProvider(date).notifier).retry();
      final retried = container.read(dayDmlProvider(date)).requireValue!;
      expect(identical(retried, first), isTrue);
      expect(glucoseReads, 1);
      expect(reads.values, everyElement(1));
      expect(retried.text, contains('"blocks":null'));
    },
  );

  test(
    'failed preparation can be retried without an existing document',
    () async {
      final date = DateTime(2026, 10, 25);
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          acceptedDaySummaryProvider(
            date,
          ).overrideWith((ref) async => dmlFixture()),
          loadDayAnalysisHistoryProvider.overrideWith((ref) {
            if (++attempts == 1) throw StateError('Initialization failed');
            return LoadDayAnalysisHistoryUseCase(
              now: () => DateTime.utc(2026, 10, 26, 8),
              loadGlucose: (_, _) async => [],
              loadStatuses: (_, _) async => [],
              loadTreatments: (_, _) async => [],
              loadMeals: (_, _) async => DayAnalysisMealBatch(meals: []),
              loadLows: (_, _) async => [],
              loadActivities: (_, _) async => [],
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(dayDmlProvider(date), (_, _) {});
      addTearDown(subscription.close);
      await expectLater(
        container.read(dayDmlProvider(date).future),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('Initialization failed'),
          ),
        ),
      );
      await container.read(dayDmlProvider(date).notifier).retry();
      final document = await container.read(dayDmlProvider(date).future);
      expect(document!.text, contains('DML/1'));
      expect(attempts, 2);
    },
  );

  test('unaccepted day never initializes history', () async {
    final date = DateTime(2026, 10, 25);
    final container = ProviderContainer(
      overrides: [
        acceptedDaySummaryProvider(date).overrideWith((ref) async => null),
        loadDayAnalysisHistoryProvider.overrideWith(
          (ref) => throw StateError('Unexpected read'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(dayDmlProvider(date).future), isNull);
  });
}
