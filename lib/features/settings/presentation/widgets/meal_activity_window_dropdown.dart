import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/async_preference_dropdown.dart';

class MealActivityWindowDropdown extends StatelessWidget {
  const MealActivityWindowDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.onSave,
  });

  final AsyncValue<int> value;
  final String label;
  final Future<void> Function(int) onSave;

  @override
  Widget build(BuildContext context) {
    final options = {
      0,
      15,
      30,
      60,
      90,
      120,
      180,
      240,
      360,
      720,
      1440,
      if (value.value != null) value.value!,
    }.toList()..sort();
    return AsyncPreferenceDropdown<int>(
      value: value,
      label: label,
      loadError: context.lang.mealActivitySettingsLoadError,
      saveError: context.lang.mealActivitySettingsSaveError,
      onSave: onSave,
      items: [
        for (final minutes in options)
          DropdownMenuItem(
            value: minutes,
            child: Text(
              minutes == 0
                  ? context.lang.mealActivityWindowDisabled
                  : minutes % 60 == 0
                  ? context.lang.durationHoursShort(minutes ~/ 60)
                  : context.lang.durationMinutesShort(minutes),
            ),
          ),
      ],
    );
  }
}
