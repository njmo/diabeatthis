import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../../common/meal_advisor/manual_meal_choice.dart';
import '../../../../../common/meal_advisor/remote/meal_decision_request_creation.dart';
import '../../../../../common/meal_advisor/remote/scheduled_meal_decision_journal.dart';
import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../common/notifications/scoped_notification_cancellation.dart';
import '../../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/drift/database_impl.dart' show MealCompanion;
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/notifications/domain/events/planned_meal_confirmation_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';

final confirmPlannedMealProvider = Provider((_) => confirmPlannedMeal);

String _cancelledKey(int mealId) => 'planned-meal-monitoring-cancelled:$mealId';

Future<void> disablePlannedMealMonitoring(
  RuntimeContext context,
  Meal meal, {
  bool manual = false,
}) async {
  final prefs = await context.container.read(sharedPrefsProvider.future);
  if (manual) {
    await saveManualMealChoice(
      prefs,
      meal.id,
      meal.plannedAt?.millisecondsSinceEpoch,
    );
  }
  await prefs.setInt(
    _cancelledKey(meal.id),
    meal.plannedAt!.millisecondsSinceEpoch,
  );
}

Future<bool> confirmPlannedMeal(
  RuntimeContext context,
  MealMonitorContext monitor,
  Meal meal,
) async {
  final plannedAt = meal.plannedAt!;
  final time = plannedAt.millisecondsSinceEpoch;
  final db = context.container.read(databaseProvider);
  // Requests issued by an earlier build can still be completed.
  if (await ScheduledMealDecisionJournal(db).load(meal.id, plannedAt) != null) {
    return true;
  }
  final prefs = await context.container.read(sharedPrefsProvider.future);
  final key = 'planned-meal-confirmed:${meal.id}';
  if (prefs.getInt(_cancelledKey(meal.id)) == time) return false;
  if (prefs.getInt(key) == time) return true;
  final askAt = plannedAt.subtract(scheduledCaregiverRequestLeadTime);
  if (clock.now().isBefore(askAt)) await context.waitUntil(askAt);

  final notification = PlannedMealConfirmationNotification(
    meal.id,
    time,
    meal.name,
  );
  final notifications = context.container.read(
    notificationsControllerForegroundProvider,
  );
  Future<bool> isCurrent() async {
    monitor.throwIfStopped(context);
    final current = await db.mealDao.getMealById(meal.id);
    return current?.status == 'planned' && current?.plannedAt == time;
  }

  if (!await isCurrent() || !clock.now().isBefore(plannedAt)) return false;
  monitor.publishStatus(context, MealMonitoringPhase.waitingForUser);
  try {
    while (clock.now().isBefore(plannedAt)) {
      final responseFuture = context
          .waitForEventWithTimeoutOrNull<MealSuggestionResponseEvent>(
            plannedAt.difference(clock.now()),
            predicate: (response) =>
                response.mealId == meal.id &&
                response.plannedAtMs == time &&
                response.maybeWhen(empty: (_, _) => false, orElse: () => true),
          );
      responseFuture.ignore();
      await notifications.show(notification);
      final response = await responseFuture;
      if (response == null || !await isCurrent()) return false;
      final input = response.maybeWhen(
        snooze: (_, _, input) => input,
        orElse: () => null,
      );
      final minutes = int.tryParse(input?.trim() ?? '');
      if (input != null &&
          (minutes == null ||
              minutes < 5 ||
              minutes > 1440 ||
              minutes % 5 != 0)) {
        continue;
      }
      return await db.transaction(() async {
        if (!await isCurrent()) return false;
        return response.when(
          agree: (_, _) => prefs.setInt(key, time),
          skip: (_, _) async {
            await disablePlannedMealMonitoring(context, meal);
            return false;
          },
          snooze: (_, _, _) async {
            await (db.update(
              db.meal,
            )..where((row) => row.id.equals(meal.id))).write(
              MealCompanion(
                plannedAt: Value(
                  plannedAt
                      .add(Duration(minutes: minutes!))
                      .millisecondsSinceEpoch,
                ),
                plannedDay: const Value(null),
                isSynced: const Value(false),
              ),
            );
            return false;
          },
          empty: (_, _) async => false,
        );
      });
    }
    return false;
  } finally {
    await notifications.cancelNotification(notification.key);
  }
}
