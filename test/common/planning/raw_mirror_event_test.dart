import 'package:diabeatthis/common/drift/mirrored_statement_table.dart';
import 'package:diabeatthis/common/family_sync/family_workflow_guard.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'raw writes and workflow locks emit shared database events after transaction',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      var calls = 0;
      final subscription = db.tableUpdates().listen((_) {
        calls++;
      });
      addTearDown(subscription.cancel);
      await db.transaction(() async {
        await db.customStatement(
          "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Walk',20,20)",
        );
        expect(calls, 0);
      });
      await Future<void>.delayed(Duration.zero);
      expect(calls, greaterThan(0));
      final before = calls;
      final guard = FamilyWorkflowGuard(db);
      guard.record('activity', 1, 'active');
      await guard.writes;
      await Future<void>.delayed(Duration.zero);
      expect(calls, greaterThan(before));
      final prior = calls;
      await db.customStatement('UPDATE family_sync_runtime SET requested=1');
      await Future<void>.delayed(Duration.zero);
      expect(calls, prior);
    },
  );
  test('only explicit mirrored tables invalidate shared state', () {
    expect(mirroredStatementTable('UPDATE "meal" SET status=?'), 'meal');
    expect(
      mirroredStatementTable('INSERT OR REPLACE INTO activity(id) VALUES(?)'),
      'activity',
    );
    expect(
      mirroredStatementTable(
        'UPDATE family_sync_outbox SET acknowledged_revision=?',
      ),
      isNull,
    );
    expect(mirroredStatementTable('SELECT * FROM meal'), isNull);
  });
}
