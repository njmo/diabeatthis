import 'dart:async';
import 'dart:io' show Platform;

import 'package:calculator_handoff/calculator_handoff.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/providers/database_provider.dart';
import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/models/notification_event_type.dart';
import '../../../core/notifications/domain/models/notification_key.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../notifications/scoped_notification_cancellation.dart';
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
        onComplete: (id) async {
          if (!ref.mounted) return;
          await ref
              .read(notificationsControllerForegroundProvider)
              .cancelNotification(
                NotificationKey(
                  type: NotificationEventType.aapsBolusSuggestion,
                  entityId: id,
                ),
              );
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
