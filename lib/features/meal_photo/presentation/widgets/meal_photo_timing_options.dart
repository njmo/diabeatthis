import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/date_time_picker.dart';
import '../../domain/models/meal_photo_timing_selection.dart';

class MealPhotoTimingOptions extends StatelessWidget {
  const MealPhotoTimingOptions({
    super.key,
    required this.selection,
    required this.now,
    required this.onModeChanged,
    required this.onDateSelected,
    this.enabled = true,
    this.pickDate,
  });
  final MealPhotoTimingSelection selection;
  final DateTime now;
  final ValueChanged<MealPhotoTimingMode> onModeChanged;
  final ValueChanged<DateTime> onDateSelected;
  final bool enabled;
  final Future<DateTime?> Function(BuildContext, DateTime)? pickDate;
  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final date = selection.plannedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.mealFlowWhen,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<MealPhotoTimingMode>(
          segments: [
            ButtonSegment(
              value: MealPhotoTimingMode.eatNow,
              label: Text(context.lang.mealPhotoEatNow),
              icon: const Icon(Icons.restaurant),
            ),
            ButtonSegment(
              value: MealPhotoTimingMode.planned,
              label: Text(context.lang.mealFlowPlan),
              icon: const Icon(Icons.event_outlined),
            ),
          ],
          selected: {selection.mode},
          onSelectionChanged: enabled
              ? (values) => onModeChanged(values.single)
              : null,
        ),
        if (selection.mode == MealPhotoTimingMode.planned) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: enabled
                ? () async {
                    final initial = date != null && date.isAfter(now)
                        ? date
                        : now.add(const Duration(minutes: 15));
                    final picked =
                        await (pickDate?.call(context, initial) ??
                            showDateTimePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(now.year, now.month, now.day),
                              lastDate: now.add(const Duration(days: 5)),
                            ));
                    if (picked != null && context.mounted) {
                      onDateSelected(picked);
                    }
                  }
                : null,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              date == null
                  ? context.lang.plannedTimeChoose
                  : '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true)}',
            ),
          ),
          if (!selection.isValidAt(now))
            Text(
              context.lang.mealPhotoFutureTimeRequired,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ],
    );
  }
}
