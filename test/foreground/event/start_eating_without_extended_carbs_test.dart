import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller_provider.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/meal_started_without_extended_carbs.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  late DatabaseImpl db;
  late MealCalculatorRequestController calculator;
  late ProviderContainer container;
  late FakeRuntimeHarness harness;
  late int mealId;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    calculator = MealCalculatorRequestController(
      store: MemoryMealCalculatorRequestStore(),
      publishWindow: (_, _) async {},
      readContext: (_) async => null,
      projectExtendedConfirmation: (_, _, _, _) async {},
      onError: (error, stack) => Error.throwWithStackTrace(error, stack),
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        mealCalculatorRequestControllerProvider.overrideWithValue(calculator),
        notificationsControllerForegroundProvider.overrideWithValue(
          FakeNotificationsController(),
        ),
      ],
    );
    harness = FakeRuntimeHarness(container: container);
    mealId = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Żurek',
            plannedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    await db.mealDao.updateMealStatus(mealId, 'bolused-waiting');
    await calculator.register(
      AapsBolusSuggestionNotificationEvent(
        mealId: mealId,
        carbs: 15,
        extendedCarbs: 25,
        extendedCarbsDelayMinutes: 45,
        extendedCarbsDurationMinutes: 120,
      ),
    );
  });

  tearDown(() async {
    harness.cancel();
    calculator.dispose();
    container.dispose();
    await db.close();
  });

  Future<String?> status() async =>
      (await db.mealDao.getMealById(mealId))?.status;

  test('plain eating confirmation still waits for planned eCarbs', () async {
    final started = await NotificationResponseEventHandler().startEating(
      mealId,
      harness.runtimeContext,
    );

    expect(started, isFalse);
    expect(await status(), 'bolused-waiting');
    expect(await calculator.hasPendingScheduledExtendedCarbs(mealId), isTrue);
  });

  test(
    'eating without eCarbs starts the meal and closes the eCarbs request',
    () async {
      ExternalEventHandler(harness.runtimeContext).handle(
        MealStartedWithoutExtendedCarbs(mealId).toExternalAppEventJson(),
      );
      await pumpEventQueue(times: 50);

      expect(await status(), 'waited-eating');
      expect(
        await calculator.hasPendingScheduledExtendedCarbs(mealId),
        isFalse,
      );
    },
  );
}
