import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_device_status_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/data_sources/stress_events/stress_event_repository.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/presentation/controllers/activity_log_details_controller.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'combined edit saves times and summary atomically and rejects stale changes',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final start = DateTime(2026, 10, 28, 17),
          end = DateTime(2026, 10, 28, 21),
          corrected = DateTime(2026, 10, 28, 18);
      await db.activityDao.insertActivity(
        ActivityCompanion.insert(
          name: 'Jujitsu',
          percentagePre: 80,
          percentagePost: 80,
        ),
      );
      await db.activityDao.insertActivityLog(
        ActivityLogCompanion.insert(
          activityId: 1,
          startedAt: start.millisecondsSinceEpoch,
          endedAt: Value(end.millisecondsSinceEpoch),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          stressEventsProvider.overrideWithValue(const AsyncData([])),
          glucoseHistoryRepositoryProvider.overrideWith(
            (ref) async => LocalGlucoseHistoryRepository(db.localMirrorDao),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) async => LocalTreatmentsHistoryRepository(db.localMirrorDao),
          ),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) async =>
                LocalDeviceStatusHistoryRepository(db.localMirrorDao),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final provider = activityLogDetailsControllerProvider(1);
      container.listen(provider, (_, _) {});
      final original = await container.read(provider.future);
      expect(original.analysis.value?.activityEnd, end);
      container.read(provider.notifier).selectTimestamp(end);
      await withClock(Clock.fixed(DateTime(2026, 10, 28, 22)), () async {
        await container
            .read(provider.notifier)
            .updateCompletedEntry(
              original: original.data,
              startedAt: start,
              endedAt: corrected,
              intensity: 'high',
              notes: '  Good session  ',
            );
      });
      final updated = await container.read(provider.future);
      expect(updated.data.endedAt, corrected);
      expect(updated.data.intensity, 'high');
      expect(updated.data.notes, 'Good session');
      expect(updated.data.summarizedAt, isNotNull);
      await expectLater(
        container
            .read(provider.notifier)
            .updateCompletedEntry(
              original: original.data,
              startedAt: start,
              endedAt: end,
              intensity: 'light',
              notes: 'Stale note',
            ),
        throwsStateError,
      );
      final persisted = await db.activityDao.getActivityLogById(1);
      expect(persisted.endedAt, corrected.millisecondsSinceEpoch);
      expect(persisted.intensity, 'high');
      expect(persisted.notes, 'Good session');

      expect(updated.selectedTimestamp, isNull);
      expect(updated.analysis.value?.activityEnd, corrected);
      expect(
        updated.analysis.value?.chartEnd,
        corrected.add(const Duration(minutes: 30)),
      );
    },
  );
}
