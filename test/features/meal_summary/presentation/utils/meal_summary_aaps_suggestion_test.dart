import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_aaps_suggestion.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldOpenAapsForMealSummaryAapsCarbs', () {
    test('opens AAPS when carbs or e-carbs are present', () {
      expect(
        shouldOpenAapsForMealSummaryAapsCarbs(
          const MealSummaryAapsCarbs(carbs: 0, extendedCarbs: 0),
        ),
        isFalse,
      );
      expect(
        shouldOpenAapsForMealSummaryAapsCarbs(
          const MealSummaryAapsCarbs(carbs: 4, extendedCarbs: 0),
        ),
        isTrue,
      );
      expect(
        shouldOpenAapsForMealSummaryAapsCarbs(
          const MealSummaryAapsCarbs(carbs: 0, extendedCarbs: 18),
        ),
        isTrue,
      );
    });
  });

  group('buildMealSummaryAapsSuggestionEvent', () {
    test('returns null when there is nothing to send to AAPS', () {
      final event = buildMealSummaryAapsSuggestionEvent(
        aapsCarbs: const MealSummaryAapsCarbs(carbs: 0, extendedCarbs: 0),
        extendedCarbsScheduleSettings:
            const ExtendedCarbsScheduleSettings.defaults(),
      );

      expect(event, isNull);
    });

    test('uses summary AAPS carbs and extended carbs schedule', () {
      final event = buildMealSummaryAapsSuggestionEvent(
        aapsCarbs: const MealSummaryAapsCarbs(carbs: 15, extendedCarbs: 26),
        extendedCarbsScheduleSettings: const ExtendedCarbsScheduleSettings(
          delayMinutes: 30,
          durationMinutes: 180,
        ),
      );

      expect(event, isNotNull);
      expect(event!.carbs, 15);
      expect(event.extendedCarbs, 26);
      expect(event.extendedCarbsDelayMinutes, 30);
      expect(event.extendedCarbsDurationMinutes, 180);
    });
  });
}
