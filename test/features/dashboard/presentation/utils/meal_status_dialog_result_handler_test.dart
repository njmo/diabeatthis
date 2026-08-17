import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
