import 'dart:async';
import 'dart:io' show Platform;

import 'package:calculator_handoff/calculator_handoff.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/providers/database_provider.dart';
import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/extended_carbs_reminder_notification.dart';
import '../../../core/notifications/domain/models/notification_event_type.dart';
import '../../../core/notifications/domain/models/notification_key.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../foreground/providers/task_event_router_provider.dart';
import '../../events/data/task/task_state_synchronization_payload.dart';
import '../../notifications/scoped_notification_cancellation.dart';
import '../meal_treatment_surplus.dart';
import 'meal_calculator_request_controller.dart';
import 'meal_calculator_request_store.dart';
import 'meal_calculator_state_use_case.dart';

final mealCalculatorRequestControllerProvider =
    Provider<MealCalculatorRequestController>((ref) {
      late final MealCalculatorRequestController controller;
      StreamSubscription<dynamic>? subscription;
      void observeDatabase() {
        if (!ref.mounted ||
            subscription != null ||
            !ref.exists(databaseProvider)) {
          return;
        }
        final db = ref.read(databaseProvider);
        if (!db.hasOpened) return;
        final query = db.selectOnly(db.meal)
          ..addColumns([db.meal.id, db.meal.status, db.meal.addOnBolusContext]);
        subscription = query.watch().listen((_) {
          unawaited(controller.refresh());
        });
      }

      MealCalculatorStateUseCase? stateUseCase() {
        if (!ref.mounted || !ref.exists(databaseProvider)) return null;
        final db = ref.read(databaseProvider);
        return db.hasOpened ? MealCalculatorStateUseCase(db) : null;
      }

      controller = MealCalculatorRequestController(
        store: !kIsWeb && Platform.isAndroid
            ? PreferencesMealCalculatorRequestStore()
            : MemoryMealCalculatorRequestStore(),
        publishWindow: const CalculatorHandoff().update,
        readExtendedReceipts: (start, end) async =>
            await stateUseCase()?.readCarbohydrateReceipts(start, end) ?? [],
        readAcceptedWizards: (id, since, carbs) async =>
            stateUseCase()?.readAcceptedWizards(id, since, carbs),
        closeWindow: const CalculatorHandoff().dismiss,
        onEntriesChanged: () {
          if (!ref.mounted) return;
          ref
              .read(taskEventRouterProvider)
              .send(const TaskStateSynchronizationPayload.mealWaitChanged());
        },
        onComplete: (id) async {
          if (!ref.mounted) return;
          final notifications = ref.read(
            notificationsControllerForegroundProvider,
          );
          for (final type in [
            NotificationEventType.aapsBolusSuggestion,
            NotificationEventType.extendedCarbsReminder,
          ]) {
            await notifications.cancelNotification(
              NotificationKey(type: type, entityId: id),
            );
          }
        },
        remindExtendedCarbs: (request, expectedStart) async {
          final event = request.event;
          final mealId = event.mealId;
          final duration = event.extendedCarbsDurationMinutes;
          if (!ref.mounted || mealId == null || duration == null) return;
          final delay = expectedStart == null
              ? event.extendedCarbsDelayMinutes ?? 0
              : (expectedStart.difference(clock.now()).inSeconds / 60).round();
          await ref
              .read(notificationsControllerForegroundProvider)
              .show(
                ExtendedCarbsReminderNotificationEvent(
                  mealId: mealId,
                  extendedCarbs: event.extendedCarbs,
                  delayMinutes: delay < 0 ? 0 : delay,
                  durationMinutes: duration,
                  additional: event.extendedCarbsAreAdditional,
                ),
              );
        },
        onTreatmentSurplus: (id) async {
          if (!ref.mounted || !ref.exists(databaseProvider)) return;
          final db = ref.read(databaseProvider);
          if (db.hasOpened) await recordMealTreatmentSurplus(db, id);
        },
        isMealRelevant: (id) async =>
            await stateUseCase()?.isMealRelevant(id) ?? true,
        readContext: (id) async {
          observeDatabase();
          return stateUseCase()?.readContext(id);
        },
        projectExtendedConfirmation: (id, requestedAt, grams, confirmed) async {
          await stateUseCase()?.projectExtendedConfirmation(
            id,
            requestedAt,
            grams,
            confirmed,
          );
        },
        onError: (error, stack) => Log.e(
          'MealCalculatorRequestController',
          'Could not update calculator instruction state',
          error: error,
          stackTrace: stack,
        ),
      );
      observeDatabase();
      ref.onDispose(() {
        controller.dispose();
        unawaited(subscription?.cancel());
      });
      return controller;
    });
