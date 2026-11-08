import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/google_authentication_providers.dart';
import '../../../family_sync/family_access_scope.dart';
import '../../../family_sync/family_planning_controller.dart';
import '../../../l10n/language.dart';
import '../../demo/meal_decision_demo_controller.dart';
import '../../demo/meal_decision_demo_request.dart';
import '../../meal_decision_preferences_provider.dart';
import 'meal_decision_demo_status_label.dart';
import 'meal_decision_demo_timeout_outcome.dart';
import 'show_meal_decision_demo.dart';

const caregiverMealDecisionDemoKey = 'caregiver:inbox';

class CaregiverMealDecisionDemoInbox extends ConsumerWidget {
  const CaregiverMealDecisionDemoInbox({super.key, this.family});
  final FamilyPlanningController? Function()? family;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mealDecisionPreferencesProvider).caregiverResponsesEnabled) {
      return const SizedBox.shrink();
    }
    final request = ref.watch(
      mealDecisionDemoControllerProvider,
    )[caregiverMealDecisionDemoKey];
    if (request == null) return const SizedBox.shrink();
    final currentFamily = family?.call();
    final pinnedScope = currentFamily == null
        ? null
        : FamilyAccessScope(currentFamily);
    if (request.mealId != null &&
        (pinnedScope == null ||
            !pinnedScope.isCurrent ||
            !request.matchesFamily(pinnedScope.owner, pinnedScope.source))) {
      return const SizedBox.shrink();
    }
    final name = ref.watch(googleAccountProvider).asData?.value?.label;
    final caregiver = name == null || name.trim().isEmpty
        ? context.lang.mealDecisionDemoCaregiver
        : name;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.mark_chat_unread_outlined),
          title: Text(
            request.status == MealDecisionDemoStatus.waiting
                ? context.lang.mealDecisionDemoNewRequest
                : request.status == MealDecisionDemoStatus.answered
                ? context.lang.mealDecisionDemoReplySentShort
                : mealDecisionDemoRequestLabel(context, request),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.mealName),
              if (request.status == MealDecisionDemoStatus.timedOut)
                MealDecisionDemoTimeoutOutcome(request: request)
              else
                Text(context.lang.mealDecisionDemoBadge),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showCaregiverMealDecisionDemo(
            context,
            requestKey: request.key,
            requestId: request.id,
            caregiverName: caregiver,
            familyScope: request.mealId == null ? null : pinnedScope,
          ),
        ),
      ),
    );
  }
}
