import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/language.dart';
import '../../meal_decision_preferences_provider.dart';
import '../../remote/meal_decision_remote_controller.dart';
import 'caregiver_meal_decision_sheet.dart';

/// The same request is accessible from its meal card and from the inbox/push.
class MealDecisionRemoteMealAction extends ConsumerWidget {
  const MealDecisionRemoteMealAction({super.key, required this.mealId});
  final int mealId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mealDecisionPreferencesProvider).caregiverResponsesEnabled) {
      return const SizedBox.shrink();
    }
    final inbox = ref.watch(mealDecisionRemoteControllerProvider);
    if (Firebase.apps.isNotEmpty &&
        inbox.accountUid != FirebaseAuth.instance.currentUser?.uid) {
      return const SizedBox.shrink();
    }
    final request = inbox.forMeal(mealId);
    if (request == null) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => showCaregiverMealDecisionRequest(context, request.id),
      icon: const Icon(Icons.mark_chat_unread_outlined),
      label: Text(
        request.status == 'waiting'
            ? context.lang.mealDecisionRemoteYourDecision
            : context.lang.mealDecisionRemoteResponded,
      ),
    );
  }
}
