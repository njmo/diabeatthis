import 'package:diabeatthis/common/meal/meal_snapshot_history_reader.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'optional snapshot history distinguishes no records from failed history',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final reader = MealSnapshotHistoryReader(db);
      final empty = await reader.read(1);
      expect(empty.available, true);
      expect(empty.snapshots, isEmpty);
      await db.customStatement('DROP TABLE meal_snapshot');
      final unavailable = await reader.read(1);
      expect(unavailable.available, false);
      expect(unavailable.snapshots, isEmpty);
    },
  );
}
