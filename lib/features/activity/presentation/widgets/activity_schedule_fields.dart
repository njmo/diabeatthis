import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/weekday_selector.dart';

class ActivityScheduleFields extends StatelessWidget {
  const ActivityScheduleFields({
    super.key,
    required this.weekdays,
    required this.onDaysChanged,
    required this.mode,
    required this.onModeChanged,
    required this.previousDayMinute,
    required this.onPreviousDayMinuteChanged,
    required this.validUntil,
    required this.onUntilChanged,
  });
  final Set<int> weekdays;
  final ValueChanged<Set<int>> onDaysChanged;
  final String mode;
  final ValueChanged<String> onModeChanged;
  final int previousDayMinute;
  final ValueChanged<int> onPreviousDayMinuteChanged;
  final DateTime? validUntil;
  final ValueChanged<DateTime?> onUntilChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      WeekdaySelector(value: weekdays, onChanged: onDaysChanged),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: mode,
        decoration: InputDecoration(
          labelText: context.lang.activityScheduleMode,
        ),
        items: [
          DropdownMenuItem(
            value: 'before',
            child: Text(context.lang.activityScheduleBefore),
          ),
          DropdownMenuItem(
            value: 'previous_day',
            child: Text(context.lang.activitySchedulePrevious),
          ),
          DropdownMenuItem(
            value: 'automatic',
            child: Text(context.lang.activityScheduleAutomatic),
          ),
        ],
        onChanged: (value) {
          if (value != null) onModeChanged(value);
        },
      ),
      if (mode == 'previous_day')
        TextButton.icon(
          icon: const Icon(Icons.schedule),
          label: Text(
            context.lang.activityScheduleEveningTime(
              TimeOfDay(
                hour: previousDayMinute ~/ 60,
                minute: previousDayMinute % 60,
              ).format(context),
            ),
          ),
          onPressed: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: previousDayMinute ~/ 60,
                minute: previousDayMinute % 60,
              ),
            );
            if (time != null) {
              onPreviousDayMinuteChanged(time.hour * 60 + time.minute);
            }
          },
        ),
      TextButton.icon(
        icon: const Icon(Icons.event),
        label: Text(
          validUntil == null
              ? context.lang.activityScheduleNoEnd
              : context.lang.activityScheduleUntil(
                  DateFormat.yMd(context.lang.localeName).format(validUntil!),
                ),
        ),
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: validUntil ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (date != null) onUntilChanged(date);
        },
      ),
      if (validUntil != null)
        TextButton(
          onPressed: () => onUntilChanged(null),
          child: Text(context.lang.activityScheduleNoEnd),
        ),
      Text(
        context.lang.activityScheduleTargetHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
