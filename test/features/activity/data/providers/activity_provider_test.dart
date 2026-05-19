import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pending activity provider returns null when there is no active log',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        getPendingActivityProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final pendingActivity = await container.read(
        getPendingActivityProvider.future,
      );

      expect(pendingActivity, isNull);
    },
  );

  test(
    'pending activity provider reacts when active log is finished',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        getPendingActivityProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(await container.read(getPendingActivityProvider.future), isNull);

      final startsAt = DateTime(2026, 5, 19, 12);
      await _seedPendingActivity(db, startsAt);
      await _settle();

      final active = container.read(getPendingActivityProvider).value;
      expect(active?.id, 1);
      expect(active?.activityName, 'Spacer');

      await db.customUpdate(
        '''
      UPDATE activity_log
      SET ended_at = ?
      WHERE id = 1
      ''',
        variables: [
          drift.Variable<int>(
            startsAt.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
          ),
        ],
        updates: {db.activityLog},
      );
      await _settle();

      expect(container.read(getPendingActivityProvider).value, isNull);
    },
  );
}

Future<void> _seedPendingActivity(DatabaseImpl db, DateTime startsAt) async {
  await db.customInsert(
    '''
    INSERT INTO activity (
      id,
      name,
      percentage_pre,
      percentage_post
    ) VALUES (1, 'Spacer', 10, 20)
    ''',
    updates: {db.activity},
  );
  await db.customInsert(
    '''
    INSERT INTO activity_log (
      id,
      activity_id,
      started_at
    ) VALUES (1, 1, ?)
    ''',
    variables: [drift.Variable<int>(startsAt.millisecondsSinceEpoch)],
    updates: {db.activityLog},
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
