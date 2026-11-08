import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'meal_advisor_minutes_dropdown.dart';

class MealAdvisorScheduleControls extends StatelessWidget {
  const MealAdvisorScheduleControls({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final ExtendedCarbsScheduleSettings settings;
  final ValueChanged<ExtendedCarbsScheduleSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumns = constraints.maxWidth >= 520;
        final delayDropdown = MealAdvisorMinutesDropdown(
          label: context.lang.settingsMealAdvisorDelayLabel,
          value: settings.delayMinutes,
          options: [15, 30, 45, 60, 90],
          onChanged: (value) {
            onChanged(settings.copyWith(delayMinutes: value));
          },
        );
        final durationDropdown = MealAdvisorMinutesDropdown(
          label: context.lang.settingsMealAdvisorDurationLabel,
          value: settings.durationMinutes,
          options: [60, 90, 120, 180, 240],
          onChanged: (value) {
            onChanged(settings.copyWith(durationMinutes: value));
          },
        );

        if (useColumns) {
          return Row(
            children: [
              Expanded(child: delayDropdown),
              const SizedBox(width: 12),
              Expanded(child: durationDropdown),
            ],
          );
        }

        return Column(
          children: [
            delayDropdown,
            const SizedBox(height: 12),
            durationDropdown,
          ],
        );
      },
    );
  }
}
