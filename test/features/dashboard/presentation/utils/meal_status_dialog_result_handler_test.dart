import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog_result.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        expect(adviceReads, 1);
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
      expect(shouldOpenAapsAfterMealStatusUpdate('eating-then-bolus'), isTrue);
      expect(shouldOpenAapsAfterMealStatusUpdate('waiting-for-bolus'), isTrue);
      expect(shouldOpenAapsAfterMealStatusUpdate('bolused-eating'), isTrue);
      expect(shouldOpenAapsAfterMealStatusUpdate('bolused-waiting'), isTrue);
      expect(shouldOpenAapsAfterMealStatusUpdate('eaten-bolused'), isTrue);
    });

    test('does not open AAPS for non-bolus status confirmations', () {
      expect(shouldOpenAapsAfterMealStatusUpdate('eating'), isFalse);
      expect(shouldOpenAapsAfterMealStatusUpdate('eaten'), isFalse);
      expect(shouldOpenAapsAfterMealStatusUpdate('waited-eating'), isFalse);
    });
  });

  group('shouldCreateAapsSuggestionForMealStatus', () {
    test('opens eat now bolus later only when extended carbs are present', () {
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
        isTrue,
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
