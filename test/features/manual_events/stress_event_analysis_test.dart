import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/stress_event_chart_ranges.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/data_sources/stress_events/stress_event_repository.dart';
import 'package:diabeatthis/core/domain/model/stress_event.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide StressEvent;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/analyze_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_analysis_charts.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'meal analysis includes manual and imported stress without changing insulin or glucose',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dataSourceConfigProvider.overrideWith(
            (ref) async => const DataSourceConfig.defaults().copyWith(
              historySource: HistorySource.local,
            ),
          ),
        ],
      );
      final time = DateTime(2026, 1, 1, 12);
      try {
        final store = container.read(stressEventRepositoryProvider);
        await LocalMirrorWriter(db.localMirrorDao).mirrorTreatments(
          TreatmentFactory().parseTreatments([
            {
              '_id': 'meal-meter',
              'eventType': 'BG Check',
              'created_at': time.toUtc().toIso8601String(),
              'glucose': 123,
              'units': 'mg/dl',
              'glucoseType': 'Finger',
            },
          ]),
          TreatmentsSource.cloud,
        );
        await store.save(
          StressEvent(
            source: 'manual',
            occurredAt: time,
            stressLevel: StressLevel.moderate,
            notes: 'Notatka',
          ),
        );
        await store.save(
          StressEvent(
            source: 'watch',
            externalId: 'stress-interval',
            occurredAt: time.subtract(const Duration(hours: 2)),
            endedAt: time.add(const Duration(minutes: 20)),
            stressLevel: StressLevel.high,
          ),
        );
        final result = await container
            .read(analyzeMealUseCaseProvider)
            .call(
              MealDetailsData(
                meal: MealRecordData(
                  id: 1,
                  name: 'Obiad',
                  status: 'eaten',
                  plannedAt: time,
                  summarizedAt: time,
                  mealTemplateId: null,
                  basedOnMealId: null,
                  notes: null,
                  createdAt: time,
                  updatedAt: time,
                  isSynced: false,
                ),
                advisorDecision: null,
                ingredients: [],
                plannedSnapshot: null,
                consumedSnapshot: null,
                statusHistory: [],
              ),
            );
        expect(result, isNotNull);
        expect(result!.totalInsulinUnits, 0);
        expect(result.glucoseReadings, isEmpty);
        expect(
          result.timelineEvents.map((event) => event.type),
          containsAll([MealTimelineEventType.stress]),
        );
        final chart = mealTimelineChartEvents(result, correctionsOnly: true);
        expect(chart, hasLength(3));
        final measurement = chart.singleWhere(
          (event) => event.label == 'Pomiar glikemii',
        );
        expect(measurement.value, '123 mg/dl · Glukometr');
        final ranges = stressEventChartRanges(
          treatments: result.treatments,
          start: result.chartStart,
          end: result.chartEnd,
          messages: lang,
        );
        expect(ranges, hasLength(1));
        expect(ranges.single.start, result.chartStart);
        expect(ranges.single.end, time.add(const Duration(minutes: 20)));
        expect(ranges.single.label, 'Stres · Wysoki');
        expect(chart.map((event) => event.label), containsAll(['Stres']));
        expect(
          result.timelineEvents
              .where(
                (event) =>
                    event.type == MealTimelineEventType.stress &&
                    event.timestamp == time,
              )
              .single
              .value,
          'Umiarkowany · Notatka',
        );
      } finally {
        container.dispose();
        await db.close();
      }
    },
  );
}
