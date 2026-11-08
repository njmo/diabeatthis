import 'package:flutter/material.dart';

import '../../../l10n/language.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';
import '../../remote/meal_decision_remote_request.dart';
import 'meal_decision_meal_reference.dart';
import 'meal_decision_remote_outcome.dart';

class CaregiverMealDecisionTimeout extends StatelessWidget {
  const CaregiverMealDecisionTimeout({
    super.key,
    required this.request,
    required this.onClose,
  });
  final MealDecisionRemoteRequest request;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => MealStartSheet(
    title: context.lang.mealDecisionCaregiverTimedOut,
    subtitle: '',
    maxHeightFactor: .75,
    showClose: false,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.timer_off_outlined,
          color: Theme.of(context).colorScheme.error,
          size: 40,
        ),
        const SizedBox(height: 16),
        MealDecisionMealReference(name: request.mealName),
        const SizedBox(height: 16),
        if (request.data['outcome'] == null)
          Text(context.lang.mealDecisionCaregiverTimedOutDescription)
        else
          MealDecisionRemoteOutcome(request: request),
      ],
    ),
    actions: FilledButton(
      onPressed: onClose,
      child: Text(context.lang.commonCloseTooltip),
    ),
  );
}
