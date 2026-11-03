import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    await db.activityDao.insertActivity(
      ActivityCompanion.insert(
        name: 'Running',
        percentagePre: 80,
        percentagePost: 80,
      ),
    );
    await db.activityDao.insertActivityLog(
      ActivityLogCompanion.insert(
        activityId: 1,
        startedAt: 1000,
        endedAt: const Value(2000),
        isSynced: const Value(true),
      ),
    );
  });
  tearDown(() => db.close());

  test(
    'summary persists without changing workout times or definition',
    () async {
      expect(
        await db.activityDao.updateCompletedActivitySummary(
          id: 1,
          intensity: 'moderate',
          notes: 'Felt good',
        ),
        isTrue,
      );
      final log = await db.activityDao.getActivityLogById(1);
      expect(log.intensity, 'moderate');
      expect(log.notes, 'Felt good');
      expect(log.startedAt, 1000);
      expect(log.endedAt, 2000);
      expect(log.isSynced, isFalse);
      expect((await db.activityDao.getActivityById(1)).name, 'Running');
      expect(
        await db.activityDao.updateCompletedActivitySummary(
          id: 1,
          intensity: null,
          notes: null,
        ),
        isTrue,
      );
      final cleared = await db.activityDao.getActivityLogById(1);
      expect(cleared.intensity, isNull);
      expect(cleared.notes, isNull);
    },
  );

  test('active and removed workouts cannot receive a summary', () async {
    await db.activityDao.insertActivityLog(
      ActivityLogCompanion.insert(activityId: 1, startedAt: 3000),
    );
    for (final id in [2, 999]) {
      expect(
        await db.activityDao.updateCompletedActivitySummary(
          id: id,
          intensity: 'high',
          notes: 'Do not save',
        ),
        isFalse,
      );
    }
    expect((await db.activityDao.getActivityLogById(2)).notes, isNull);
  });
}
