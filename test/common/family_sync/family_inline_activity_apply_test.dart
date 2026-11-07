import 'package:diabeatthis/common/family_sync/apply_family_plan_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_plan_apply_test.dart' show localPlan;

void main() {
  for (final operation in ['planActivity', 'startActivity', 'logActivity']) {
    test(
      '$operation atomically creates canonical activity and does not duplicate on replay',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final now = DateTime.now().millisecondsSinceEpoch;
        final plan = await localPlan(
          db,
          operation,
          values: {
            'activityId': null,
            'activity': {
              'name': 'Walk',
              'percentagePre': 20,
              'percentagePost': 30,
              'durationMinutes': 30,
            },
            'startedAt': operation == 'planActivity'
                ? now + 3600000
                : operation == 'logActivity'
                ? now - 3600000
                : now,
            if (operation == 'planActivity') 'durationMinutes': 30,
            if (operation == 'logActivity') 'endedAt': now - 1800000,
          },
        );
        await ApplyFamilyPlanUseCase(db)('child', plan);
        await ApplyFamilyPlanUseCase(db)('child', plan);
        expect(await db.select(db.activity).get(), hasLength(1));
        expect((await db.select(db.activity).getSingle()).name, 'Walk');
        final journal = await db
            .customSelect('SELECT outcome FROM family_plan_journal')
            .getSingle();
        expect(journal.read<String>('outcome'), 'applied');
        if (operation == 'planActivity') {
          expect(await db.select(db.activityOccurrence).get(), hasLength(1));
        } else {
          expect(await db.select(db.activityLog).get(), hasLength(1));
        }
      },
    );
  }
  test('blocked immediate start also rolls back the inline definition', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Existing',20,20)",
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'INSERT INTO activity_log(activity_id,started_at) VALUES(1,?)',
      [now - 60000],
    );
    final plan = await localPlan(
      db,
      'startActivity',
      values: {
        'activityId': null,
        'activity': {
          'name': 'New walk',
          'percentagePre': 20,
          'percentagePost': 30,
          'durationMinutes': null,
        },
        'startedAt': now,
      },
    );
    await ApplyFamilyPlanUseCase(db)('child', plan);
    expect(await db.select(db.activity).get(), hasLength(1));
    expect(await db.select(db.activityLog).get(), hasLength(1));
    final journal = await db
        .customSelect('SELECT outcome FROM family_plan_journal')
        .getSingle();
    expect(journal.read<String>('outcome'), 'rejected');
  });
}
