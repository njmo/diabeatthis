import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_event_router_provider.dart';
import '../../app/providers/foreground_task_state_provider.dart';
import '../../core/data/provider/shared_prefs_provider.dart';
import '../events/data/app/execute_command_event.dart';
import 'meal_decision_preference_keys.dart';
import 'meal_decision_preferences.dart';

export 'meal_decision_preference_keys.dart';

final mealDecisionPreferencesProvider = Provider<MealDecisionPreferences>((
  ref,
) {
  final prefs = ref.watch(sharedPrefsProvider).asData?.value;
  final value = prefs?.getString(mealDecisionPreferencesKey);
  if (value == null &&
      prefs?.getBool(aiAssistedMealAdvisorPreferenceKey) == true) {
    return const MealDecisionPreferences(method: MealDecisionMethod.ai);
  }
  return MealDecisionPreferences.decode(value);
});

final saveMealDecisionPreferencesProvider = Provider(
  (ref) => (MealDecisionPreferences preferences) async {
    if (preferences.deferralMinutes < 1 || preferences.deferralMinutes > 180) {
      throw ArgumentError('Deferral minutes must be between 1 and 180');
    }
    if (!preferences.allowManualDecision &&
        preferences.timeoutFallback == MealDecisionTimeoutFallback.manual) {
      throw ArgumentError(
        'Manual fallback requires manual decisions to be enabled',
      );
    }
    if (preferences.method == MealDecisionMethod.ai) {
      throw StateError('AI meal decisions are temporarily unavailable');
    }
    final prefs = await ref.read(sharedPrefsProvider.future);
    final previous = MealDecisionPreferences.decode(
      prefs.getString(mealDecisionPreferencesKey),
    );
    if (!await prefs.setString(
      mealDecisionPreferencesKey,
      preferences.encode(),
    )) {
      throw StateError('Meal decision configuration was not saved');
    }
    if (ref.mounted) {
      ref.invalidate(mealDecisionPreferencesProvider);
      if (previous.method != preferences.method) _syncMealDecisionMethod(ref);
    }
  },
);

/// Setup must not leave a preference from a failed attempt behind.
final configureMealDecisionPreferencesProvider = Provider(
  (ref) =>
      (
        MealDecisionPreferences? preferences,
        Future<void> Function() apply,
      ) async {
        if (preferences == null) {
          await apply();
          return;
        }
        final prefs = await ref.read(sharedPrefsProvider.future);
        final previous = prefs.getString(mealDecisionPreferencesKey);
        await ref.read(saveMealDecisionPreferencesProvider)(preferences);
        try {
          await apply();
        } catch (_) {
          // Preserve a newer independent edit, if there was one.
          if (prefs.getString(mealDecisionPreferencesKey) ==
              preferences.encode()) {
            final restored = previous == null
                ? await prefs.remove(mealDecisionPreferencesKey)
                : await prefs.setString(mealDecisionPreferencesKey, previous);
            if (!restored) {
              throw StateError('Meal decision configuration rollback failed');
            }
            if (ref.mounted) {
              ref.invalidate(mealDecisionPreferencesProvider);
              if (MealDecisionPreferences.decode(previous).method !=
                  preferences.method) {
                _syncMealDecisionMethod(ref);
              }
            }
          }
          rethrow;
        }
      },
);

void _syncMealDecisionMethod(Ref ref) {
  if (!ref.read(foregroundTaskStateProvider).alive) return;
  ref.read(appEventRouterProvider).send(
    const ExecuteCommandEvent.syncSettings(
      data: {mealDecisionPreferencesKey: ''},
    ),
  );
}
