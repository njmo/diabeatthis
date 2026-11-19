import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_finished_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog_result.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/pending_notifications_controller.dart';

void main() {
  for (final persistedStatus in ['waiting-for-bolus', 'interrupted']) {
    testWidgets('skip scopes cleanup with stored status $persistedStatus', (
      tester,
    ) async {
      final db = drift.DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final mealId = (await tester.runAsync(
        () => db
            .into(db.meal)
            .insert(
              drift.MealCompanion.insert(
                name: 'Obiad',
                plannedAt: const Value(0),
              ),
            ),
      ))!;
      await tester.runAsync(
        () => db.mealDao.tryUpdateMealStatus(mealId, persistedStatus),
      );
      final meal = Meal(id: mealId, name: 'Obiad', status: 'waiting-for-bolus');
      final notifications = PendingNotificationsController();
      final current = FinishedEatingNotificationEvent(mealId: mealId);
      final consent = TempTargetNotificationEvent.meal(entityId: mealId);
      final instructions = AapsBolusSuggestionNotificationEvent(
        mealId: mealId,
        carbs: 45,
      );
      final other = FinishedEatingNotificationEvent(mealId: mealId + 1);
      final activity = ActivityFinishedNotificationEvent(
        activityLogId: mealId,
        activityName: 'Spacer',
      );
      await notifications.show(current);
      await notifications.show(consent);
      await notifications.show(instructions);
      await notifications.show(other);
      await notifications.show(activity);

      late BuildContext context;
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notificationsControllerUiProvider.overrideWithValue(notifications),
          ],
          child: Consumer(
            builder: (widgetContext, widgetRef, _) {
              context = widgetContext;
              ref = widgetRef;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.runAsync(
        () => handleMealStatusDialogResult(
          context: context,
          ref: ref,
          meal: meal,
          result: const MealStatusUpdateResult('skipped'),
        ),
      );

      final rejected = persistedStatus == 'interrupted';
      final stored = await tester.runAsync(
        () => db.mealDao.getMealById(mealId),
      );
      expect(stored?.status, rejected ? 'interrupted' : 'skipped');
      expect(notifications.contains(current), rejected);
      expect(notifications.contains(consent), rejected);
      expect(notifications.contains(instructions), rejected);
      expect(notifications.contains(other), isTrue);
      expect(notifications.contains(activity), isTrue);
      expect(notifications.cancelAllCalled, isFalse);
      if (rejected) expect(notifications.cancelledIds, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final alreadySaved in [true, false]) {
    testWidgets(
      'handles status without repeating a completed write: $alreadySaved',
      (tester) async {
        const meal = Meal(id: 1, name: 'Obiad', status: 'planned');
        var currentStatus = 'bolused-eating';
        var writes = 0;
        var adviceReads = 0;
        Future<void>? operation;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              updateMealProvider.overrideWith((ref, args) async {
                writes++;
                currentStatus = args.$2;
              }),
              getMealAdviceProvider(meal).overrideWith((ref) async {
                adviceReads++;
                return null;
              }),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () {
                      operation = handleMealStatusDialogResult(
                        context: context,
                        ref: ref,
                        meal: meal,
                        result: MealStatusUpdateResult(
                          'eating-then-bolus',
                          alreadySaved: alreadySaved,
                        ),
                      );
                    },
                    child: const Text('Handle'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Handle'));
        await tester.pumpAndSettle();
        await operation;
        expect(writes, alreadySaved ? 0 : 1);
        expect(
          currentStatus,
          alreadySaved ? 'bolused-eating' : 'eating-then-bolus',
        );
        expect(adviceReads, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('shouldOpenSummaryAfterMealStatusUpdate', () {
    test('opens summary for regular eaten statuses', () {
      expect(shouldOpenSummaryAfterMealStatusUpdate('eaten'), isTrue);
      expect(shouldOpenSummaryAfterMealStatusUpdate('eaten-bolused'), isTrue);
    });

    test('keeps eaten add-on meal on the list until user opens it', () {
      expect(shouldOpenSummaryAfterMealStatusUpdate('eaten-extra'), isFalse);
    });
  });

  group('shouldOpenAapsAfterMealStatusUpdate', () {
    test('opens AAPS for statuses that require AAPS entry', () {
      expect(shouldOpenAapsAfterMealStatusUpdate('waiting-for-bolus'), isTrue);
      expect(shouldOpenAapsAfterMealStatusUpdate('bolused-eating'), isTrue);
      expect(shouldOpenAapsAfterMealStatusUpdate('bolused-waiting'), isTrue);
      expect(shouldOpenAapsAfterMealStatusUpdate('eaten-bolused'), isTrue);
    });

    test('does not open AAPS for non-bolus status confirmations', () {
      expect(shouldOpenAapsAfterMealStatusUpdate('eating-then-bolus'), isFalse);
      expect(shouldOpenAapsAfterMealStatusUpdate('eating'), isFalse);
      expect(shouldOpenAapsAfterMealStatusUpdate('eaten'), isFalse);
      expect(shouldOpenAapsAfterMealStatusUpdate('waited-eating'), isFalse);
    });
  });

  group('shouldCreateAapsSuggestionForMealStatus', () {
    test('defers eat-first eCarbs until consumption is confirmed', () {
      expect(
        shouldCreateAapsSuggestionForMealStatus(
          'eating-then-bolus',
          extendedCarbsGrams: 0,
        ),
        isFalse,
      );
      expect(
        shouldCreateAapsSuggestionForMealStatus(
          'eating-then-bolus',
          extendedCarbsGrams: 20,
        ),
        isFalse,
      );
    });

    test('keeps regular bolus statuses independent from extended carbs', () {
      expect(
        shouldCreateAapsSuggestionForMealStatus(
          'eaten-bolused',
          extendedCarbsGrams: 0,
        ),
        isTrue,
      );
      expect(
        shouldCreateAapsSuggestionForMealStatus(
          'bolused-waiting',
          extendedCarbsGrams: 0,
        ),
        isTrue,
      );
    });
  });

  group('AapsBolusSuggestionNotificationEvent', () {
    test('renders bolus and eat now suggestion', () {
      const event = AapsBolusSuggestionNotificationEvent(carbs: 45);

      expect(event.title, 'Podaj 45g');
      expect(event.body, isEmpty);
      expect(event.toPayload(), isEmpty);
      expect(event.extendedCarbsDeliveryMode, isNull);
      expect(event.extendedCarbsDelayMinutes, isNull);
      expect(event.extendedCarbsDurationMinutes, isNull);
    });

    test(
      'renders only extended carbs for eat now bolus later with e-carbs',
      () {
        const event = AapsBolusSuggestionNotificationEvent(
          carbs: 0,
          extendedCarbs: 25,
          extendedCarbsDelayMinutes: 25,
          extendedCarbsDurationMinutes: 120,
        );

        expect(event.title, 'Wpisz extended 25g za 25 min przez 2 godz.');
      },
    );

    test('fails fast without carbs and e-carbs', () {
      const event = AapsBolusSuggestionNotificationEvent(carbs: 0);

      expect(() => event.title, throwsA(isA<StateError>()));
    });

    test('fails fast for e-carbs without schedule', () {
      const event = AapsBolusSuggestionNotificationEvent(
        carbs: 0,
        extendedCarbs: 25,
      );

      expect(() => event.title, throwsA(isA<StateError>()));
    });

    test('renders bolus wait suggestion', () {
      const event = AapsBolusSuggestionNotificationEvent(carbs: 45);

      expect(event.title, 'Podaj 45g');
    });

    test('renders extended carbs grams in title', () {
      const event = AapsBolusSuggestionNotificationEvent(
        carbs: 15,
        extendedCarbs: 25,
        extendedCarbsDelayMinutes: 25,
        extendedCarbsDurationMinutes: 120,
      );

      expect(event.title, 'Podaj 15g, extended 25g za 25 min przez 2 godz.');
    });

    test('renders negative carbs as carbs entry', () {
      const event = AapsBolusSuggestionNotificationEvent(carbs: -8);

      expect(event.title, 'Wpisz -8g');
    });
  });
}
