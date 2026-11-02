import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';

void main() {
  const meal = Meal(
    id: 1,
    name: 'Meal',
    status: 'waiting-for-bolus',
    carbs: 20,
  );
  const schedule = ExtendedCarbsScheduleSettings(
    delayMinutes: 30,
    durationMinutes: 90,
  );
  final advice = MealAdvice.full(
    MealDecision.eatNowBolusLater,
    null,
    DateTime(2026, 11, 1),
    extendedCarbs: const WbtExtendedCarbsSuggestion(
      kcal: 110,
      wbt: 1.1,
      grams: 11,
      scheduleSettings: schedule,
    ),
  );

  Future<AapsBolusSuggestionNotificationEvent> openSuggestion(
    WidgetTester tester, {
    drift.DatabaseImpl? database,
    int? consumedCarbs,
    int? consumedExtendedCarbs,
  }) async {
    final notifications = FakeNotificationsController();
    Future<void>? operation;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith(
            (ref) =>
                database ??
                (throw StateError(
                  'Explicit amounts must not query the database',
                )),
          ),
          getMealAdviceProvider(meal).overrideWith((ref) async => advice),
          notificationsControllerUiProvider.overrideWithValue(notifications),
          aapsLauncherProvider.overrideWithValue(ConsumedEcarbsAapsLauncher()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () {
                  operation = openAapsAfterBolusStatusUpdateIfNeeded(
                    context: context,
                    ref: ref,
                    meal: meal,
                    status: 'waiting-for-bolus',
                    consumedCarbs: consumedCarbs,
                    consumedExtendedCarbs: consumedExtendedCarbs,
                  );
                },
                child: const Text('Open calculator'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open calculator'));
    await tester.pumpAndSettle();
    await operation;
    return notifications.shownEvents.single
        as AapsBolusSuggestionNotificationEvent;
  }

  for (final actualExtended in [0, 5, 22]) {
    testWidgets(
      'explicit consumed $actualExtended eCarbs replaces the old 11 without a database read',
      (tester) async {
        final event = await openSuggestion(
          tester,
          consumedCarbs: 10,
          consumedExtendedCarbs: actualExtended,
        );
        expect(event.carbs, 10);
        expect(event.extendedCarbs, actualExtended);
        expect(event.extendedCarbsDelayMinutes, actualExtended > 0 ? 30 : null);
        expect(
          event.extendedCarbsDurationMinutes,
          actualExtended > 0 ? 90 : null,
        );
        expect(advice.extendedCarbs.grams, 11);
      },
    );
  }

  for (final confirmed in [false, true]) {
    testWidgets(
      'reopening the calculator uses ${confirmed ? 'confirmed consumption' : 'the plan before eating'}',
      (tester) async {
        final db = drift.DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        await db.customInsert('''INSERT INTO ingredient
        (id, name, carbs_per_100g, fat_per_100g, fiber_per_100g, protein_per_100g, nutrition_confidence)
        VALUES (1, 'Meal ingredient', 20, 10, 0, 5, 1)''');
        await db
            .into(db.meal)
            .insert(
              drift.MealCompanion.insert(
                id: const Value(1),
                name: 'Meal',
                plannedAt: 1000,
                status: const Value('waiting-for-bolus'),
                consumptionConfirmedEndedAt: Value(confirmed ? 2000 : null),
              ),
            );
        await db.customInsert('''INSERT INTO meal_ingredients
        (id, meal_id, ingredient_id, amount, consumed_amount, quantity_confidence)
        VALUES (1, 1, 1, 100, 50, 1)''');
        final event = await openSuggestion(tester, database: db);
        expect(event.carbs, confirmed ? 10 : 20);
        expect(event.extendedCarbs, confirmed ? 0 : 11);
        expect((await db.mealDao.getMealById(1))?.status, 'waiting-for-bolus');
        expect(advice.extendedCarbs.grams, 11);
      },
    );
  }
}

class ConsumedEcarbsAapsLauncher extends AapsLauncher {
  @override
  Future<AapsLaunchResult> openAaps() async => AapsLaunchResult.opened;
}
