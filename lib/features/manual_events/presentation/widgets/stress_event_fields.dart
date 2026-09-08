import 'package:flutter/material.dart';

import '../../../../common/history/stress_event_labels.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/stress_level.dart';
import 'stress_end_time_field.dart';

class StressEventFields extends StatelessWidget {
  const StressEventFields({
    super.key,
    required this.level,
    required this.startedAt,
    required this.endedAt,
    required this.onLevelChanged,
    required this.onEndChanged,
  });

  final StressLevel level;
  final DateTime startedAt;
  final DateTime? endedAt;
  final ValueChanged<StressLevel> onLevelChanged;
  final ValueChanged<DateTime?> onEndChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.lang.manualEventStressLevel),
      Wrap(
        spacing: 8,
        children: [
          for (final value in StressLevel.values)
            ChoiceChip(
              label: Text(stressLevelLabel(context.lang, value)),
              selected: value == level,
              onSelected: (_) => onLevelChanged(value),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.lang.manualEventStressEndEnabled),
        value: endedAt != null,
        onChanged: (enabled) {
          final suggested = startedAt.add(const Duration(hours: 1));
          onEndChanged(enabled ? suggested : null);
        },
      ),
      if (endedAt != null)
        StressEndTimeField(
          startedAt: startedAt,
          value: endedAt!,
          onChanged: onEndChanged,
        ),
    ],
  );
}
