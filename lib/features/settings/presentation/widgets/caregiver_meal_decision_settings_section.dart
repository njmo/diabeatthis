import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'meal_decision_settings.dart';
import 'settings_section_card.dart';

class CaregiverMealDecisionSettingsSection extends StatelessWidget {
  const CaregiverMealDecisionSettingsSection({super.key});
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    icon: Icons.question_answer_outlined,
    title: context.lang.mealDecisionResponsesTitle,
    children: const [MealDecisionSettings(caregiver: true)],
  );
}
