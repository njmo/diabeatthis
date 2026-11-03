import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/controlled_preferences.dart';

void main() {
  test(
    'saving schedule persists both fields and refreshes the same context source',
    () async {
      final prefs = ControlledPreferences();
      final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWith((ref) async => prefs)],
      );
      addTearDown(container.dispose);
      final initial = await container.read(
        extendedCarbsScheduleSettingsProvider.future,
      );
      expect(initial.delayMinutes, 45);
      expect(initial.durationMinutes, 120);
      await container
          .read(extendedCarbsScheduleSettingsControllerProvider)
          .save(
            const ExtendedCarbsScheduleSettings(
              delayMinutes: 30,
              durationMinutes: 180,
            ),
          );
      final result = await container.read(
        extendedCarbsScheduleSettingsProvider.future,
      );
      expect(result.delayMinutes, 30);
      expect(result.durationMinutes, 180);
      expect(prefs.writes, [
        (key: 'meal_advisor_extended_carbs_delay_minutes', value: 30),
        (key: 'meal_advisor_extended_carbs_duration_minutes', value: 180),
      ]);
    },
  );
}
