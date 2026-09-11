import 'dart:convert';

import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_device_status_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/data_sources/providers/on_demand_history_repositories_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/similar_meals_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_analysis_charts.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  late bool offline;

  setUp(() {
    offline = true;
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dataSourceConfigProvider.overrideWithValue(
          AsyncData(
            const DataSourceConfig.defaults().copyWith(
              historySource: HistorySource.local,
            ),
          ),
        ),
        onDemandHistoryRepositoriesProvider.overrideWith((ref) {
          if (offline) throw StateError('Offline');
          return (
            glucose: LocalGlucoseHistoryRepository(db.localMirrorDao),
            treatments: LocalTreatmentsHistoryRepository(db.localMirrorDao),
            deviceStatuses: LocalDeviceStatusHistoryRepository(
              db.localMirrorDao,
            ),
          );
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'shared refresh invalidates active contexts and stays available',
    () async {
      offline = false;
      final meal = await db
          .into(db.meal)
          .insertReturning(
            MealCompanion.insert(
              name: 'Meal',
              plannedAt: DateTime(2026, 5, 24, 13).millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      final provider = mealDetailsControllerProvider(meal.id);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final matches = similarMealsProvider(initial.details);
      final matchSubscription = container.listen(matches, (_, _) {});
      addTearDown(matchSubscription.close);
      final previous = container.read(matches.future);
      await previous;
      await container.read(provider.notifier).downloadHistory();
      final refreshed = container.read(matches.future);
      expect(identical(previous, refreshed), false);
      await refreshed;
      expect(container.read(provider).value!.showHistoryDownload, true);
      expect(container.read(provider).value!.isDownloadingHistory, false);
    },
  );

  test(
    'preserves local analysis and clears busy state after download failure',
    () async {
      final meal = await db
          .into(db.meal)
          .insertReturning(
            MealCompanion.insert(
              name: 'Obiad',
              plannedAt: DateTime(2026, 5, 24, 13).millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      final provider = mealDetailsControllerProvider(meal.id);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final before = await container.read(provider.future);
      expect(before.analysis, isNotNull);
      final controller = container.read(provider.notifier);
      final download = controller.downloadHistory();
      expect(container.read(provider).value!.isDownloadingHistory, isTrue);
      await expectLater(download, throwsA(isA<StateError>()));
      final after = container.read(provider).value!;
      expect(after.isDownloadingHistory, isFalse);
      expect(after.analysis, same(before.analysis));
      expect(after.details, same(before.details));
    },
  );

  test(
    'retrospective history groups wizard with carbs and insulin delivery',
    () async {
      final start = DateTime(2026, 5, 24, 9, 41);
      final wizardTime = start.add(const Duration(seconds: 32));
      final bolusTime = start.add(const Duration(seconds: 35));
      final treatments = TreatmentFactory().parseTreatments([
        {
          '_id': 'carbs',
          'eventType': 'Meal Bolus',
          'created_at': start
              .add(const Duration(seconds: 31))
              .toUtc()
              .toIso8601String(),
          'carbs': 23,
          'insulin': null,
          'isValid': true,
        },
        {
          '_id': 'calculator',
          'eventType': 'Bolus Wizard',
          'created_at': wizardTime.toUtc().toIso8601String(),
          'date': wizardTime.millisecondsSinceEpoch,
          'glucose': 125,
          'units': 'mg/dl',
          'bolusCalculatorResult': jsonEncode({
            'carbs': 23.0,
            'totalInsulin': 1.4,
          }),
          'isValid': true,
        },
        {
          '_id': 'delivery',
          'eventType': 'Meal Bolus',
          'created_at': bolusTime.toUtc().toIso8601String(),
          'date': bolusTime.millisecondsSinceEpoch,
          'insulin': 1.4,
          'carbs': null,
          'isValid': true,
        },
      ]);
      await LocalMirrorWriter(
        db.localMirrorDao,
      ).mirrorTreatments(treatments, TreatmentsSource.cloud);
      final meal = await db
          .into(db.meal)
          .insertReturning(
            MealCompanion.insert(
              name: 'Breakfast',
              plannedAt: start.millisecondsSinceEpoch,
              status: const Value('summarized'),
            ),
          );
      final provider = mealDetailsControllerProvider(meal.id);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final state = await container.read(provider.future);
      final analysis = state.analysis!;
      expect(analysis.totalInsulinUnits, 1.4);
      final events = mealTimelineChartEvents(analysis, correctionsOnly: true);
      expect(
        events
            .where((event) => event.label == 'Kalkulator bolusa')
            .single
            .timestamp,
        wizardTime,
      );
      expect(events.where((event) => event.label == 'Bolus'), isEmpty);
      expect(analysis.totalTreatmentCarbs, 23);
      final summary = InsulinBolusSummary.fromTreatments(
        treatments: analysis.treatments,
        start: start,
        end: analysis.chartEnd,
      );
      expect(summary.manualCount, 0);
      expect(summary.wizardCount, 1);
      expect(summary.wizardUnits, 1.4);
      expect(events.any((event) => event.label == 'Korekta ręczna'), isFalse);
    },
  );

  test('does not build meal page state for low treatment meals', () async {
    final lowTreatment = await db
        .into(db.meal)
        .insertReturning(
          MealCompanion.insert(
            name: 'Dosłodzenie',
            plannedAt: DateTime(2026, 5, 24, 13).millisecondsSinceEpoch,
            purpose: const Value('lowTreatment'),
            status: const Value('confirmed'),
          ),
        );

    final subscription = container.listen(
      mealDetailsControllerProvider(lowTreatment.id),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.pump();
    await container.pump();

    final state = container.read(
      mealDetailsControllerProvider(lowTreatment.id),
    );
    expect(state.hasError, isTrue);
    expect(state.error, isA<LowTreatmentMealPageException>());
  });
}
