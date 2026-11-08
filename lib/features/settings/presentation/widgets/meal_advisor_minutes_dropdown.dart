import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class MealAdvisorMinutesDropdown extends StatelessWidget {
  const MealAdvisorMinutesDropdown({
    super.key,
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
        if (value == null) {
          return;
        }
        onChanged(value);
      },
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes == 60) {
      return lang.durationOneHourShort;
    }
    if (minutes > 0 && minutes % 60 == 0) {
      return lang.durationHoursShort(minutes ~/ 60);
    }
    return lang.durationMinutesShort(minutes);
  }
}
