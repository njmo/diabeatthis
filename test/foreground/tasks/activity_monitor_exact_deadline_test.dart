import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/task/base/runtime_context.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/activity_monitor_context.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/finish_activity_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/monitor_active_activity_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/helpers/activity_temp_target_monitor.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

class DisabledTargetSupervision extends ActivityTempTargetMonitor {
  @override
  Future<bool> isEnabled(RuntimeContext context) async => false;
}

void main() {
  test('45-minute activity finishes at its exact deadline without a periodic tick', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final activityId = await db.into(db.activity).insert(ActivityCompanion.insert(
      name: 'WF', percentagePre: 80, percentagePost: 100,
    ));
    final end = clock.now().add(const Duration(milliseconds: 500));
    final start = end.subtract(const Duration(minutes: 45));
    final id = await db.into(db.activityLog).insert(ActivityLogCompanion.insert(
      activityId: activityId, startedAt: start.millisecondsSinceEpoch,
    ));
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityTempTargetMonitorProvider.overrideWithValue(DisabledTargetSupervision()),
    ]);
    final harness = FakeRuntimeHarness(container: container);
    addTearDown(harness.dispose);
    final result = await const MonitorActiveActivityExecutor().execute(
      harness.runtimeContext,
      ActivityMonitorContext(activityLogId: id, activityId: activityId,
        activityName: 'WF', startsAt: start, durationMinutes: 45),
    ).timeout(const Duration(seconds: 5));
    expect(result, isA<FinishActivityExecutor>());
    expect((await db.activityDao.getActivityLogById(id)).endedAt, end.millisecondsSinceEpoch);
    expect(harness.emittedTicks, isNotEmpty);
    expect(harness.activeWaitersCount, 0);
  });
}
