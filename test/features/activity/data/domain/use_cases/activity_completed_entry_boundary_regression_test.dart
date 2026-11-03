import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/save_activity_summary_use_case.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/update_completed_activity_entry_use_case.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/update_completed_activity_times_use_case.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_details_data.dart';
import 'package:diabeatthis/features/activity/data/providers/save_activity_summary_provider.dart';
import 'package:diabeatthis/features/activity/presentation/controllers/activity_summary_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/regression/scripted_read.dart';

void main() {
  final start = DateTime.utc(2026, 11, 1, 10);
  final end = DateTime.utc(2026, 11, 1, 11);
  final correctedEnd = DateTime.utc(2026, 11, 1, 11, 30);
  final original = ActivityLogDetailsData(
    id: 7,
    activityId: 2,
    activityName: 'Walk',
    percentagePre: 80,
    percentagePost: 90,
    durationMinutes: 60,
    startedAt: start,
    endedAt: end,
    intensity: null,
    notes: null,
    isSynced: false,
    createdAt: start,
    updatedAt: end,
  );

  for (final failure in [null, 'times', 'summary']) {
    test(
      'completed entry keeps both writes in one transaction; failure=$failure',
      () async {
        final events = <String>[];
        final times = ScriptedRead<bool>('times write', [
          (
            arguments: [7, start, end, start, correctedEnd],
            respond: () {
              events.add('times');
              return failure != 'times';
            },
          ),
        ]);
        final summary = ScriptedRead<bool>(
          'summary write',
          failure == 'times'
              ? []
              : [
                  (
                    arguments: [7, 'moderate', 'updated'],
                    respond: () {
                      events.add('summary');
                      return failure != 'summary';
                    },
                  ),
                ],
        );
        final useCase = UpdateCompletedActivityEntryUseCase(
          updateTimes: UpdateCompletedActivityTimesUseCase(
            now: () => DateTime.utc(2026, 11, 2),
            updateIfUnchanged:
                ({
                  required id,
                  required expectedStart,
                  required expectedEnd,
                  required startedAt,
                  required endedAt,
                }) =>
                    times([id, expectedStart, expectedEnd, startedAt, endedAt]),
          ),
          saveSummary: SaveActivitySummaryUseCase(
            saveCompleted:
                ({required id, required intensity, required notes}) =>
                    summary([id, intensity, notes]),
          ),
          transaction: (action) async {
            events.add('begin');
            try {
              await action();
              events.add('commit');
            } catch (_) {
              events.add('rollback');
              rethrow;
            }
          },
        );
        final operation = useCase(
          id: 7,
          original: original,
          startedAt: start,
          endedAt: correctedEnd,
          intensity: 'moderate',
          notes: ' updated ',
        );
        if (failure == null) {
          await operation;
          expect(events, ['begin', 'times', 'summary', 'commit']);
        } else {
          await expectLater(operation, throwsStateError);
          expect(
            events,
            failure == 'times'
                ? ['begin', 'times', 'rollback']
                : ['begin', 'times', 'summary', 'rollback'],
          );
        }
        times.verifyComplete();
        summary.verifyComplete();
      },
    );
  }

  test(
    'summary controller publishes errors and recovers without direct database reads',
    () async {
      final writes = ScriptedRead<bool>('summary', [
        (arguments: [7, 'moderate', 'first'], respond: () => false),
        (arguments: [7, 'moderate', 'retry'], respond: () => true),
      ]);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Unexpected direct database read'),
          ),
          saveActivitySummaryUseCaseProvider.overrideWithValue(
            SaveActivitySummaryUseCase(
              saveCompleted:
                  ({required id, required intensity, required notes}) =>
                      writes([id, intensity, notes]),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        activitySummaryControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(
        activitySummaryControllerProvider.notifier,
      );
      await expectLater(
        controller.save(
          activityLogId: 7,
          intensity: 'moderate',
          notes: 'first',
        ),
        throwsStateError,
      );
      expect(container.read(activitySummaryControllerProvider).hasError, true);
      await controller.save(
        activityLogId: 7,
        intensity: 'moderate',
        notes: 'retry',
      );
      expect(
        container.read(activitySummaryControllerProvider),
        const AsyncData<void>(null),
      );
      writes.verifyComplete();
    },
  );
}
