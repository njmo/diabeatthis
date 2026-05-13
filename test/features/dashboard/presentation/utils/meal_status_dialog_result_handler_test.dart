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
    test('opens AAPS for statuses started by bolus action', () {
      expect(shouldOpenAapsAfterMealStatusUpdate('bolused-eating'), isTrue);
      expect(shouldOpenAapsAfterMealStatusUpdate('bolused-waiting'), isTrue);
    });

    test('does not open AAPS for non-bolus status confirmations', () {
      expect(shouldOpenAapsAfterMealStatusUpdate('eating'), isFalse);
      expect(shouldOpenAapsAfterMealStatusUpdate('eaten'), isFalse);
      expect(shouldOpenAapsAfterMealStatusUpdate('eaten-bolused'), isFalse);
    });
  });

  group('AapsBolusSuggestionNotificationEvent', () {
    test('renders bolus and eat now suggestion', () {
      const event = AapsBolusSuggestionNotificationEvent(
        mealId: 1,
        mealName: 'Obiad',
        carbs: 45,
        status: 'bolused-eating',
      );

      expect(event.title, 'Podaj 45g teraz');
      expect(event.body, isEmpty);
      expect(event.toPayload(), isEmpty);
    });

    test('renders bolus wait suggestion', () {
      const event = AapsBolusSuggestionNotificationEvent(
        mealId: 1,
        mealName: 'Obiad',
        carbs: 45,
        status: 'bolused-waiting',
        waitMinutes: 15,
      );

      expect(event.title, 'Podaj 45g teraz');
    });

    test('renders extended carbs schedule in title', () {
      const event = AapsBolusSuggestionNotificationEvent(
        mealId: 1,
        mealName: 'Obiad',
        carbs: 15,
        status: 'bolused-eating',
        extendedCarbs: 25,
        extendedCarbsDelayMinutes: 25,
        extendedCarbsDurationMinutes: 120,
      );

      expect(event.title, 'Podaj 15g teraz i 25g za 25 min przez 2 godz.');
    });
  });
}
