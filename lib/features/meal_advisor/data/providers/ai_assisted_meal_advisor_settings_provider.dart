import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/meal_advisor/meal_decision_preferences.dart';
import '../../../../common/meal_advisor/meal_decision_preferences_provider.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';

export '../../../../common/meal_advisor/meal_decision_preference_keys.dart'
    show aiAssistedMealAdvisorPreferenceKey;

/// Temporarily unavailable independently of a previously saved opt-in.
final aiAssistedMealAdvisorAvailableProvider = Provider<bool>((ref) => false);

/// Local opt-in. An unavailable preference never enables extra history work.
final aiAssistedMealAdvisorEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(aiAssistedMealAdvisorAvailableProvider) &&
      ref.watch(mealDecisionPreferencesProvider).method ==
          MealDecisionMethod.ai,
);

final aiAssistedMealAdvisorSettingsControllerProvider = Provider(
  (ref) => AiAssistedMealAdvisorSettingsController(ref),
);

class AiAssistedMealAdvisorSettingsController {
  final Ref ref;
  const AiAssistedMealAdvisorSettingsController(this.ref);
  Future<void> save(bool enabled) async {
    if (enabled && !ref.read(aiAssistedMealAdvisorAvailableProvider)) {
      throw StateError('AI-assisted Meal Advisor is temporarily unavailable');
    }
    final prefs = await ref.read(sharedPrefsProvider.future);
    final saved = await prefs.setBool(
      aiAssistedMealAdvisorPreferenceKey,
      enabled,
    );
    if (!saved) {
      throw StateError('Could not save AI-assisted Meal Advisor preference');
    }
    if (prefs.containsKey(mealDecisionPreferencesKey)) {
      final current = MealDecisionPreferences.decode(
        prefs.getString(mealDecisionPreferencesKey),
      );
      final method = enabled
          ? MealDecisionMethod.ai
          : current.method == MealDecisionMethod.ai
          ? MealDecisionMethod.app
          : current.method;
      if (!await prefs.setString(
        mealDecisionPreferencesKey,
        current.copyWith(method: method).encode(),
      )) {
        throw StateError('Could not save meal decision method');
      }
    }
    if (ref.mounted) {
      ref.invalidate(mealDecisionPreferencesProvider);
      ref.invalidate(aiAssistedMealAdvisorEnabledProvider);
    }
  }
}
