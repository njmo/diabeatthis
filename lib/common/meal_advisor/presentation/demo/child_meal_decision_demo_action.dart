import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../../../features/dashboard/presentation/utils/show_meal_status_dialog.dart';
import '../../../auth/google_authentication_providers.dart';
import '../../../l10n/language.dart';
import '../../demo/meal_decision_demo_controller.dart';
import '../../meal_decision_preferences.dart';
import '../../meal_decision_preferences_provider.dart';
import 'meal_decision_demo_status_label.dart';
import 'show_meal_decision_demo.dart';

class ChildMealDecisionDemoAction extends ConsumerWidget {
  const ChildMealDecisionDemoAction({
    super.key,
    required this.mealId,
    required this.mealName,
    this.enabled = true,
  });
  final int mealId;
  final String mealName;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(mealDecisionPreferencesProvider).method !=
        MealDecisionMethod.caregiver) {
      return const SizedBox.shrink();
    }
    final real =
        Firebase.apps.isNotEmpty &&
        ref.watch(googleAccountProvider).asData?.value != null;
    if (real) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.question_answer_outlined),
        label: Text(context.lang.mealDecisionDemoAsk),
        onPressed: !enabled
            ? null
            : () async {
                final stored = await ref
                    .read(databaseProvider)
                    .mealDao
                    .getMealById(mealId);
                if (stored == null || !context.mounted) return;
                final meal = stored.toDomain();
                final result = await showMealStatusDialog(
                  context: context,
                  meal: meal,
                  startImmediately: true,
                );
                if (result != null && context.mounted) {
                  await handleMealStatusDialogResult(
                    context: context,
                    ref: ref,
                    meal: meal,
                    result: result,
                  );
                }
              },
      );
    }
    final key = 'patient:$mealId';
    final request = ref.watch(mealDecisionDemoControllerProvider)[key];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        icon: Icon(
          request == null
              ? Icons.question_answer_outlined
              : Icons.mark_chat_unread_outlined,
        ),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request == null
                  ? context.lang.mealDecisionDemoAsk
                  : mealDecisionDemoRequestLabel(context, request),
            ),
            Text(
              context.lang.mealDecisionDemoBadge,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        onPressed: enabled
            ? () => showChildMealDecisionDemo(
                context,
                requestKey: key,
                mealName: mealName,
              )
            : null,
      ),
    );
  }
}
