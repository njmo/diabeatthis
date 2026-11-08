import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../meal_decision_preferences.dart';
import 'meal_decision_timeout_field.dart';
import 'meal_manual_decision_field.dart';

class MealDecisionMethodField extends StatelessWidget {
  const MealDecisionMethodField({
    super.key,
    required this.value,
    required this.caregiverAvailable,
    required this.onChanged,
    this.enabled = true,
    this.timeoutFallback = MealDecisionTimeoutFallback.app,
    this.onTimeoutFallbackChanged,
    this.allowManualDecision = true,
    this.onAllowManualDecisionChanged,
  });
  final MealDecisionMethod value;
  final bool allowManualDecision;
  final ValueChanged<bool>? onAllowManualDecisionChanged;
  final MealDecisionTimeoutFallback timeoutFallback;
  final ValueChanged<MealDecisionTimeoutFallback>? onTimeoutFallbackChanged;
  final bool caregiverAvailable;
  final bool enabled;
  final ValueChanged<MealDecisionMethod> onChanged;

  @override
  Widget build(BuildContext context) => RadioGroup<MealDecisionMethod>(
    groupValue: value,
    onChanged: (method) {
      if (enabled &&
          method != null &&
          method != MealDecisionMethod.ai &&
          (method != MealDecisionMethod.caregiver || caregiverAvailable)) {
        onChanged(method);
      }
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final method in MealDecisionMethod.values)
          RadioListTile<MealDecisionMethod>(
            contentPadding: EdgeInsets.zero,
            value: method,
            enabled:
                enabled &&
                method != MealDecisionMethod.ai &&
                (method != MealDecisionMethod.caregiver || caregiverAvailable),
            title: Text(switch (method) {
              MealDecisionMethod.app => context.lang.mealDecisionApp,
              MealDecisionMethod.ai => context.lang.mealDecisionAi,
              MealDecisionMethod.caregiver =>
                context.lang.mealDecisionCaregiver,
            }),
            subtitle: Text(switch (method) {
              MealDecisionMethod.app => context.lang.mealDecisionAppDescription,
              MealDecisionMethod.ai =>
                context.lang.settingsAiAdvisorUnavailable,
              MealDecisionMethod.caregiver =>
                caregiverAvailable
                    ? context.lang.mealDecisionCaregiverDescription
                    : context.lang.mealDecisionFamilyRequired,
            }),
          ),
        MealManualDecisionField(
          value: allowManualDecision,
          onChanged: enabled ? onAllowManualDecisionChanged : null,
        ),
        if (value == MealDecisionMethod.caregiver) ...[
          const SizedBox(height: 12),
          MealDecisionTimeoutField(
            value: timeoutFallback,
            allowManualDecision: allowManualDecision,
            onChanged: enabled ? onTimeoutFallbackChanged : null,
          ),
          const SizedBox(height: 12),
          Text(
            context.lang.mealDecisionDeliveryPending,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}
