import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/provider/shared_prefs_provider.dart';

const aiAssistedMealAdvisorPreferenceKey = 'meal_advisor_ai_assisted';

/// Local opt-in. An unavailable preference never enables extra history work.
final aiAssistedMealAdvisorEnabledProvider = Provider<bool>(
  (ref) =>
      ref
          .watch(sharedPrefsProvider)
          .asData
          ?.value
          .getBool(aiAssistedMealAdvisorPreferenceKey) ??
      false,
);

final aiAssistedMealAdvisorSettingsControllerProvider = Provider(
  (ref) => AiAssistedMealAdvisorSettingsController(ref),
);

class AiAssistedMealAdvisorSettingsController {
  final Ref ref;
  const AiAssistedMealAdvisorSettingsController(this.ref);
  Future<void> save(bool enabled) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final saved = await prefs.setBool(
      aiAssistedMealAdvisorPreferenceKey,
      enabled,
    );
    if (!saved) {
      throw StateError('Could not save AI-assisted Meal Advisor preference');
    }
    if (ref.mounted) ref.invalidate(aiAssistedMealAdvisorEnabledProvider);
  }
}
