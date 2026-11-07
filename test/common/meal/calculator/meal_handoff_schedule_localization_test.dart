import 'dart:ui';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/calculator/meal_handoff_instruction.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const event = AapsBolusSuggestionNotificationEvent(
    carbs: 30,
    extendedCarbs: 12,
    extendedCarbsDelayMinutes: 45,
    extendedCarbsDurationMinutes: 120,
  );

  for (final locale in ['pl', 'en']) {
    test('handoff schedule uses explicit $locale translations', () {
      LanguageStrings.setSelectedLocale(Locale(locale == 'pl' ? 'en' : 'pl'));
      addTearDown(() => LanguageStrings.setSelectedLocale(const Locale('pl')));
      final strings = lookupAppLocalizations(Locale(locale));
      final instruction = MealHandoffInstruction.build(event, strings);

      expect(
        instruction.steps.last.value,
        strings.aapsPipSchedule(
          strings.durationMinutesShort(45),
          strings.durationHoursShort(2),
        ),
      );
    });
  }
}
