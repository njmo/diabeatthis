import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/date_time_picker.dart';
import '../../domain/models/meal_photo_timing_selection.dart';

/// Editing a date is explicit; dismissing the picker leaves "now" unchanged.
class MealPhotoTimingSummary extends StatelessWidget {
  const MealPhotoTimingSummary({
    super.key,
    required this.selection,
    required this.now,
    required this.onDateSelected,
    required this.onUseNow,
    this.enabled = true,
    this.pickDate,
  });
  final MealPhotoTimingSelection selection;
  final DateTime now;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onUseNow;
  final bool enabled;
  final Future<DateTime?> Function(BuildContext, DateTime)? pickDate;

  @override
  Widget build(BuildContext context) {
    final date = selection.plannedAt;
    final planned =
        selection.mode == MealPhotoTimingMode.planned && date != null;
    final localizations = MaterialLocalizations.of(context);
    final label = planned
        ? '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true)}'
        : context.lang.mealPhotoTimeNow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(label)),
              IconButton(
                tooltip: context.lang.mealPhotoEditTime,
                icon: const Icon(Icons.edit_outlined),
                onPressed: !enabled
                    ? null
                    : () async {
                        final initial = planned && date.isAfter(now)
                            ? date
                            : now.add(const Duration(minutes: 15));
                        final picked =
                            await (pickDate?.call(context, initial) ??
                                showDateTimePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  ),
                                  lastDate: now.add(const Duration(days: 5)),
                                ));
                        if (picked != null && context.mounted) {
                          onDateSelected(picked);
                        }
                      },
              ),
              if (planned)
                TextButton(
                  onPressed: enabled ? onUseNow : null,
                  child: Text(context.lang.mealPhotoTimeNow),
                ),
            ],
          ),
        ),
        if (!selection.isValidAt(now))
          Text(
            context.lang.mealPhotoFutureTimeRequired,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
