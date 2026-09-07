import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/date_time_picker.dart';
import '../../../../../common/widgets/date_time_shortcuts.dart';

class MealPlannedTimeField extends FormField<DateTime> {
  MealPlannedTimeField({super.key, required ValueChanged<DateTime> onChanged})
    : super(
        validator: (value) => value == null ? lang.addMealDateRequired : null,
        builder: (state) {
          void select(DateTime value) {
            state.didChange(value);
            onChanged(value);
          }

          final context = state.context;
          final selected = state.value;
          final localizations = MaterialLocalizations.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.lang.addMealPlannedDateLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              DateTimeShortcuts(onSelected: select),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () async {
                  final now = clock.now();
                  final firstDate = now.subtract(const Duration(days: 1));
                  final lastDate = now.add(const Duration(days: 5));
                  final initialDate =
                      selected == null ||
                          selected.isBefore(firstDate) ||
                          selected.isAfter(lastDate)
                      ? now
                      : selected;
                  final value = await showDateTimePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (value != null && state.mounted) select(value);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    labelText: context.lang.plannedTimeChoose,
                    border: const OutlineInputBorder(),
                    errorText: state.errorText,
                  ),
                  child: Text(
                    selected == null
                        ? context.lang.addMealDateTimePlaceholder
                        : '${localizations.formatMediumDate(selected)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(selected), alwaysUse24HourFormat: true)}',
                  ),
                ),
              ),
            ],
          );
        },
      );
}
