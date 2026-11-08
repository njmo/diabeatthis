import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'meal_activity_windows_settings.dart';
import 'meal_advisor_schedule_controls.dart';
import 'meal_decision_settings.dart';
import 'settings_section_card.dart';

class MealAdvisorSettingsSection extends ConsumerWidget {
  const MealAdvisorSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(extendedCarbsScheduleSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionCard(
          icon: Icons.restaurant_menu_outlined,
          title: context.lang.settingsMealAdvisorTitle,
          subtitle: context.lang.mealDecisionConfigurationDescription,
          children: const [MealDecisionSettings()],
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          icon: Icons.directions_run_outlined,
          title: context.lang.mealActivityWindowsTitle,
          children: const [MealActivityWindowsSettings(showHeading: false)],
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          icon: Icons.schedule_outlined,
          title: context.lang.mealStartScheduleLabel,
          subtitle: context.lang.settingsMealAdvisorSubtitle,
          children: [
            settingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Text(context.lang.settingsMealAdvisorError(error)),
              data: (settings) => MealAdvisorScheduleControls(
                settings: settings,
                onChanged: (next) => ref
                    .read(extendedCarbsScheduleSettingsControllerProvider)
                    .save(next),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
