import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/google_authentication_providers.dart';
import '../../meal_decision_preferences.dart';
import '../../meal_decision_preferences_provider.dart';
import '../../remote/meal_decision_remote_controller.dart';
import 'meal_decision_caregiver_roster.dart';

class ChildMealDecisionMealAction extends ConsumerWidget {
  const ChildMealDecisionMealAction({super.key, required this.mealId});

  final int mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(mealDecisionPreferencesProvider).method !=
            MealDecisionMethod.caregiver ||
        Firebase.apps.isEmpty) {
      return const SizedBox.shrink();
    }
    final uid = ref.watch(googleAccountProvider).asData?.value?.uid;
    if (uid == null) return const SizedBox.shrink();
    final inbox = ref.watch(mealDecisionRemoteControllerProvider);
    final request = inbox.accountUid == uid ? inbox.forMeal(mealId) : null;
    return request == null
        ? const SizedBox.shrink()
        : MealDecisionCaregiverRoster(request: request, compact: true);
  }
}
