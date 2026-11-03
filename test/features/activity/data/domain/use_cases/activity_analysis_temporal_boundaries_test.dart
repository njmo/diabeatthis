import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/stress_event.dart';
import 'package:diabeatthis/core/domain/model/stress_event_treatment.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/load_activity_log_analysis_use_case.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_details_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/regression/scripted_device_status_history_repository.dart';
import '../../../../../helpers/regression/scripted_glucose_history_repository.dart';
import '../../../../../helpers/regression/scripted_read.dart';
import '../../../../../helpers/regression/scripted_treatments_history_repository.dart';

void main() {
  final start = DateTime.utc(2026, 9, 1, 12);
  final end = start.add(const Duration(hours: 1));
  ActivityLogDetailsData log({bool completed = true}) => ActivityLogDetailsData(
    id: 7,
    activityId: 2,
    activityName: 'Walk',
    percentagePre: 80,
    percentagePost: 90,
    durationMinutes: 60,
    startedAt: start,
    endedAt: completed ? end : null,
    intensity: null,
    notes: null,
    isSynced: false,
    createdAt: start,
    updatedAt: end,
  );

  test(
    'unfinished activity does not request history or fabricate an outcome',
    () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Unexpected database read'),
          ),
          glucoseHistoryRepositoryProvider.overrideWith(
            (ref) => throw StateError('Unexpected glucose read'),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) => throw StateError('Unexpected treatment read'),
          ),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) => throw StateError('Unexpected device read'),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(loadActivityLogAnalysisUseCaseProvider)(
          log(completed: false),
        ),
        isNull,
      );
    },
  );

  for (final failure in [null, 'glucose', 'treatments', 'device', 'before']) {
    test(
      'activity history uses explicit windows and propagates source failure: $failure',
      () async {
        final chartStart = start.subtract(const Duration(minutes: 30));
        final chartEnd = end.add(const Duration(minutes: 30));
        final fetchStart = chartStart.subtract(const Duration(hours: 4));
        final error = StateError('Source unavailable: $failure');
        StressEventTreatment stress(DateTime from, DateTime until) =>
            StressEventTreatment(
              StressEvent(
                occurredAt: from,
                endedAt: until,
                source: 'manual',
                stressLevel: StressLevel.high,
              ),
            );
        TemporaryTarget target(DateTime from, int minutes, {int top = 140}) =>
            TemporaryTarget(
              nightscoutId: null,
              createdAt: from,
              durationInMiliseconds: minutes * 60000,
              duration: minutes,
              targetBottom: 100,
              targetTop: top,
            );
        final overlappingStress = stress(fetchStart, start);
        final endedStress = stress(
          fetchStart,
          chartStart.subtract(const Duration(milliseconds: 1)),
        );
        final futureStress = stress(
          chartEnd.add(const Duration(milliseconds: 1)),
          chartEnd.add(const Duration(hours: 1)),
        );
        final overlappingTarget = target(
          chartStart.subtract(const Duration(minutes: 10)),
          20,
        );
        final endsAtBoundary = target(
          chartStart.subtract(const Duration(minutes: 10)),
          10,
        );
        final startsAtBoundary = target(chartEnd, 20);
        final ordinaryTarget = target(start, 30, top: 110);
        final glucose = ScriptedRead<List<Glucose>>('glucose', [
          (
            arguments: [chartStart, chartEnd],
            respond: () {
              if (failure == 'glucose') throw error;
              return [];
            },
          ),
        ]);
        final treatments = ScriptedRead<List<Treatment>>(
          'treatments',
          failure == 'glucose'
              ? []
              : [
                  (
                    arguments: [fetchStart, chartEnd],
                    respond: () {
                      if (failure == 'treatments') throw error;
                      return [
                        overlappingStress,
                        endedStress,
                        futureStress,
                        overlappingTarget,
                        endsAtBoundary,
                        startsAtBoundary,
                        ordinaryTarget,
                      ];
                    },
                  ),
                ],
        );
        final devices = ScriptedRead<List<DeviceStatus>>(
          'device',
          ['glucose', 'treatments'].contains(failure)
              ? []
              : [
                  (
                    arguments: [chartStart, chartEnd],
                    respond: () {
                      if (failure == 'device') throw error;
                      return [];
                    },
                  ),
                ],
        );
        final before = ScriptedRead<DeviceStatus?>(
          'before',
          ['glucose', 'treatments', 'device'].contains(failure)
              ? []
              : [
                  (
                    arguments: [start],
                    respond: () {
                      if (failure == 'before') throw error;
                      return null;
                    },
                  ),
                ],
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith(
              (ref) => throw StateError('Unexpected database read'),
            ),
            glucoseHistoryRepositoryProvider.overrideWith(
              (ref) async => ScriptedGlucoseHistoryRepository(glucose),
            ),
            treatmentsHistoryRepositoryProvider.overrideWith(
              (ref) async => ScriptedTreatmentsHistoryRepository(treatments),
            ),
            deviceStatusHistoryRepositoryProvider.overrideWith(
              (ref) async =>
                  ScriptedDeviceStatusHistoryRepository(devices, before),
            ),
          ],
        );
        addTearDown(container.dispose);
        final operation = container.read(
          loadActivityLogAnalysisUseCaseProvider,
        )(log());
        if (failure != null) {
          await expectLater(operation, throwsA(same(error)));
        } else {
          final result = (await operation)!;
          expect(result.chartStart, chartStart);
          expect(result.chartEnd, chartEnd);
          expect(result.activityTargets, [overlappingTarget]);
          expect(result.chartTreatments, contains(overlappingStress));
          expect(result.chartTreatments, isNot(contains(endedStress)));
          expect(result.chartTreatments, isNot(contains(futureStress)));
          expect(result.deviceStatusAtStart, isNull);
          expect(result.iobAtStart, isNull);
          expect(result.cobAtStart, isNull);
          expect(result.averageGlucoseDuringActivity, isNull);
          expect(result.preActivityMeals, isEmpty);
        }
        glucose.verifyComplete();
        treatments.verifyComplete();
        devices.verifyComplete();
        before.verifyComplete();
      },
    );
  }
}
