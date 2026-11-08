import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal_advisor/presentation/meal_decision_method_field.dart';
import '../../../../../common/meal_advisor/presentation/meal_decision_responses_field.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_step_heading.dart';

class SetupMealAdvisorModule extends StatelessWidget {
  const SetupMealAdvisorModule({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  Widget build(BuildContext context) {
    final caregiver = controller.state.mode == SetupDeviceMode.caregiver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetupStepHeading(
          title: caregiver
              ? context.lang.mealDecisionResponsesTitle
              : context.lang.settingsMealAdvisorTitle,
          description: caregiver
              ? context.lang.mealDecisionResponsesDetails
              : context.lang.mealDecisionConfigurationDescription,
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          icon: Icons.restaurant_menu_outlined,
          title: context.lang.settingsMealAdvisorTitle,
          children: [
            if (caregiver)
              MealDecisionResponsesField(
                enabled: controller
                    .state
                    .mealDecisionPreferences
                    .caregiverResponsesEnabled,
                onChanged: controller.setCaregiverResponses,
                deferralMinutes:
                    controller.state.mealDecisionPreferences.deferralMinutes,
                onDeferralChanged: controller.setDeferralMinutes,
              )
            else
              MealDecisionMethodField(
                value: controller.state.mealDecisionPreferences.method,
                allowManualDecision: controller
                    .state
                    .mealDecisionPreferences
                    .allowManualDecision,
                onAllowManualDecisionChanged: controller.setAllowManualDecision,
                caregiverAvailable: controller.caregiverDecisionAvailable,
                onChanged: controller.selectMealDecisionMethod,
                timeoutFallback:
                    controller.state.mealDecisionPreferences.timeoutFallback,
                onTimeoutFallbackChanged:
                    controller.setMealDecisionTimeoutFallback,
              ),
          ],
        ),
      ],
    );
  }
}
