import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import '../../../../common/family/family_pairing_member.dart';
import '../../../../common/family/family_providers.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/meal_advisor/meal_decision_preferences.dart';
import '../../../../common/meal_advisor/meal_decision_preferences_provider.dart';
import '../../../../common/meal_advisor/presentation/meal_decision_method_field.dart';
import '../../../../common/meal_advisor/presentation/meal_decision_responses_field.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';

class MealDecisionSettings extends HookConsumerWidget {
  const MealDecisionSettings({super.key, this.caregiver = false});
  final bool caregiver;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPrefsProvider);
    final preferences = ref.watch(mealDecisionPreferencesProvider);
    final saving = useState(false);
    final failed = useState(false);
    final account = ref.watch(googleAccountProvider);
    final uid = account.isLoading || account.hasError
        ? null
        : account.asData?.value?.uid;
    final status = uid == null
        ? null
        : ref.watch(secureFamilyStatusProvider(uid));
    final available =
        status != null &&
        !status.isLoading &&
        !status.hasError &&
        status.asData!.value.members.any(
          (member) => member.role == FamilyMemberRole.caregiver,
        );
    Future<void> save(MealDecisionPreferences next) async {
      saving.value = true;
      failed.value = false;
      try {
        await ref.read(saveMealDecisionPreferencesProvider)(next);
      } catch (_) {
        if (context.mounted) failed.value = true;
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    if (!prefs.hasValue) {
      return prefs.hasError
          ? Text(context.lang.mealDecisionSaveFailed)
          : const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caregiver)
          MealDecisionResponsesField(
            deferralMinutes: preferences.deferralMinutes,
            onDeferralChanged: saving.value
                ? null
                : (value) => save(
                    preferences.copyWith(
                      method: MealDecisionMethod.app,
                      deferralMinutes: value,
                    ),
                  ),
            enabled: preferences.caregiverResponsesEnabled,
            onChanged: saving.value
                ? null
                : (value) => save(
                    preferences.copyWith(
                      method: MealDecisionMethod.app,
                      caregiverResponsesEnabled: value,
                    ),
                  ),
          )
        else
          MealDecisionMethodField(
            value: preferences.method,
            allowManualDecision: preferences.allowManualDecision,
            onAllowManualDecisionChanged: (allowed) => save(
              preferences.copyWith(
                allowManualDecision: allowed,
                timeoutFallback: allowed
                    ? preferences.timeoutFallback
                    : MealDecisionTimeoutFallback.app,
              ),
            ),
            timeoutFallback: preferences.timeoutFallback,
            onTimeoutFallbackChanged: saving.value
                ? null
                : (value) => save(preferences.copyWith(timeoutFallback: value)),
            enabled: !saving.value,
            caregiverAvailable: available,
            onChanged: (method) => save(preferences.copyWith(method: method)),
          ),
        if (failed.value) Text(context.lang.mealDecisionSaveFailed),
      ],
    );
  }
}
