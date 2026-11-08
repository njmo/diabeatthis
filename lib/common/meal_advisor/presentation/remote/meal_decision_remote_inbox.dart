import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/language.dart';
import '../../meal_decision_preferences_provider.dart';
import '../../remote/meal_decision_remote_controller.dart';
import 'caregiver_meal_decision_sheet.dart';

class MealDecisionRemoteInboxView extends ConsumerWidget {
  const MealDecisionRemoteInboxView({super.key});
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final request in inbox.requests.where((r) => r.pending))
          Card.outlined(
            child: ListTile(
              leading: const Icon(Icons.mark_chat_unread_outlined),
              title: Text(request.mealName),
              subtitle: Text(
                request.status == 'waiting'
                    ? context.lang.mealDecisionRemoteYourDecision
                    : context.lang.mealDecisionRemoteResponded,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  showCaregiverMealDecisionRequest(context, request.id),
            ),
          ),
      ],
    );
  }
}
