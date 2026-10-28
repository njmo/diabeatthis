import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'AI-assisted mode defaults off and its opt-in survives a new container',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer open() => ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWith((ref) async => prefs)],
      );
      final container = open();
      addTearDown(container.dispose);
      await container.read(sharedPrefsProvider.future);
      expect(container.read(aiAssistedMealAdvisorEnabledProvider), isFalse);
      await container
          .read(aiAssistedMealAdvisorSettingsControllerProvider)
          .save(true);
      expect(container.read(aiAssistedMealAdvisorEnabledProvider), isTrue);
      final reopened = open();
      addTearDown(reopened.dispose);
      await reopened.read(sharedPrefsProvider.future);
      expect(reopened.read(aiAssistedMealAdvisorEnabledProvider), isTrue);
      await reopened
          .read(aiAssistedMealAdvisorSettingsControllerProvider)
          .save(false);
      expect(reopened.read(aiAssistedMealAdvisorEnabledProvider), isFalse);
      expect(prefs.getBool(aiAssistedMealAdvisorPreferenceKey), isFalse);
    },
  );
}
