import 'package:diabeatthis/common/family_sync/apply_family_plan_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_plan_apply_test.dart' show localPlan;

void main() {
  test(
    'an activity started early is protected even before a monitor phase was published',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO activity(name,percentage_pre,percentage_post,duration_minutes) VALUES('Walk',10,10,30)",
      );
      final start = DateTime.now()
          .add(const Duration(hours: 3))
          .millisecondsSinceEpoch;
      final plan = await localPlan(
        db,
        'planActivity',
        values: {'activityId': 1, 'startedAt': start, 'durationMinutes': 30},
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      await db.customStatement('UPDATE activity_log SET started_at=?', [
        DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      ]);
      final move = await localPlan(
        db,
        'moveActivity',
        targetId: 1,
        values: {'startedAt': start + 3600000},
      );
      move['id'] = 'f' * 32;
      await ApplyFamilyPlanUseCase(db)('child', move);
      expect(
        (await db
                .customSelect(
                  "SELECT outcome FROM family_plan_journal WHERE operation_id='${move['id']}'",
                )
                .getSingle())
            .read<String>('outcome'),
        'rejected',
      );
      expect(
        (await db.select(db.activityOccurrence).getSingle()).startedAt,
        start,
      );
    },
  );
}
