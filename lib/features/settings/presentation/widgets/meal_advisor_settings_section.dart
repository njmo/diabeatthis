import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import '../../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'settings_section_card.dart';

class MealAdvisorSettingsSection extends ConsumerWidget {
  const MealAdvisorSettingsSection({super.key});

  static const _delayOptions = [15, 30, 45, 60, 90];
  static const _durationOptions = [60, 90, 120, 180, 240];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(extendedCarbsScheduleSettingsProvider);

    return SettingsSectionCard(
      icon: Icons.restaurant_menu_outlined,
      title: 'Meal Advisor',
      subtitle:
          'Ustaw domyślne rozłożenie extended carbs dla WBT większego niż 1.',
      children: [
        settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Błąd ustawień Meal Advisora: $error'),
          data: (settings) => _MealAdvisorSettingsControls(
            settings: settings,
            onChanged: (next) => ref
                .read(extendedCarbsScheduleSettingsControllerProvider)
                .save(next),
          ),
        ),
      ],
    );
  }
}

class _MealAdvisorSettingsControls extends StatelessWidget {
  const _MealAdvisorSettingsControls({
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
        final delayDropdown = _MinutesDropdown(
          label: 'Start extended carbs',
          value: settings.delayMinutes,
          options: MealAdvisorSettingsSection._delayOptions,
          onChanged: (value) {
            onChanged(settings.copyWith(delayMinutes: value));
          },
        );
        final durationDropdown = _MinutesDropdown(
          label: 'Czas trwania',
          value: settings.durationMinutes,
          options: MealAdvisorSettingsSection._durationOptions,
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

class _MinutesDropdown extends StatelessWidget {
  const _MinutesDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeOptions = [...options];
    if (!safeOptions.contains(value)) {
      safeOptions.add(value);
    }
    safeOptions.sort();

    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in safeOptions)
          DropdownMenuItem(value: option, child: Text(_formatMinutes(option))),
      ],
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes == 60) return '1 godz.';
    if (minutes > 0 && minutes % 60 == 0) return '${minutes ~/ 60} godz.';
    return '$minutes min';
  }
}
