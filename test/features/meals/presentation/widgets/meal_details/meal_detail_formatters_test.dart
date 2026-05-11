import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_detail_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mealStatusLabel', () {
    test('shows add-on statuses explicitly', () {
      expect(mealStatusLabel('eating-extra'), 'W trakcie dokładki');
      expect(mealStatusLabel('eaten-extra'), 'Zjedzony z dokładką');
    });

    test('shows regular eating statuses without raw status values', () {
      expect(mealStatusLabel('eating'), 'W trakcie jedzenia');
      expect(
        mealStatusLabel('eating-then-bolus'),
        'Jedzenie, bolus po posiłku',
      );
      expect(mealStatusLabel('waited-eating'), 'Po oczekiwaniu, jedzenie');
    });
  });

  group('timelineEventValueLabel', () {
    test('formats linked meal status values', () {
      final event = MealTimelineEventData(
        timestamp: DateTime(2026),
        type: MealTimelineEventType.localMeal,
        label: 'Kolacja',
        value: 'eaten-extra',
      );

      expect(timelineEventValueLabel(event), 'Zjedzony z dokładką');
    });

    test('formats current status marker', () {
      final event = MealTimelineEventData(
        timestamp: DateTime(2026),
        type: MealTimelineEventType.mealStatus,
        label: 'eaten-extra',
        value: 'current status',
      );

      expect(timelineEventValueLabel(event), 'Aktualny status');
    });
  });
}
