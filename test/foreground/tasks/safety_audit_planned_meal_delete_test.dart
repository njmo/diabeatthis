import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/collector/meal_status_collector.dart';
import 'package:diabeatthis/foreground/collector/next_meal_collector.dart';
import 'package:diabeatthis/foreground/event/internal/meal_event.dart';
import 'package:diabeatthis/foreground/runtime/workflow_scheduler.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/utils/pending_notifications_controller.dart';
import '../../helpers/common/wait_for_condition.dart';

void main() {
  test('planned meal deletion is reflected by the real database query', () async {
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final plannedAt = DateTime.now().add(const Duration(hours: 2));
    await db.customInsert(
      "INSERT INTO meal (id, name, planned_at, status) VALUES (1, 'Lunch', ?, 'planned')",
      variables: [Variable<int>(plannedAt.millisecondsSinceEpoch)],
    );

    expect((await db.mealDao.getNearestMeal())?.id, 1);
    await db.mealDao.deleteMealAndGeneratedData(1);
    expect(await db.mealDao.getNearestMeal(), isNull);
  });

  test('deleting the only monitored planned meal clears the monitor', () async {
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final plannedAt = DateTime.now().add(const Duration(hours: 2));
    await db.customInsert(
      "INSERT INTO meal (id, name, planned_at, status) VALUES (1, 'Lunch', ?, 'planned')",
      variables: [Variable<int>(plannedAt.millisecondsSinceEpoch)],
    );
    expect((await db.mealDao.getNearestMeal())?.id, 1);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerForegroundProvider.overrideWithValue(
          PendingNotificationsController(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final scheduler = WorkflowScheduler();
    addTearDown(scheduler.dispose);
    final context = scheduler.createContext(container);
    final task = MealMonitorTask();
    scheduler.startTask(task, context);
    final initialCandidate = context.waitForEvent<NextMealEvent>(
      predicate: (event) => event.mealId == 1,
    );
    final collector = NextMealCollector();
    collector.start(CollectorContext.fromRuntimeContext(context));
    addTearDown(collector.dispose);
    final statusCollector = MealStatusCollector();
    statusCollector.start(CollectorContext.fromRuntimeContext(context));
    addTearDown(statusCollector.dispose);

    expect(
      (await initialCandidate.timeout(const Duration(seconds: 5))).mealId,
      1,
    );
    await waitForCondition(
      () => task.state is MonitorUntilMeal,
      description: 'the planned meal to enter monitoring',
    );
    expect(task.state, isA<MonitorUntilMeal>());

    await db.mealDao.deleteMealAndGeneratedData(1);
    expect(await db.mealDao.getNearestMeal(), isNull);
    await waitForCondition(
      () => task.state is MealMonitorStateIdle,
      description: 'the monitor to clear the deleted planned meal',
    );

    // Expected after removal is published to the monitor task.
    expect(task.state, isA<MealMonitorStateIdle>());
  });
}
