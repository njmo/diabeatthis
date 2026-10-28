import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../common/l10n/language.dart';
import '../../data/drafts/activity_schedule_draft.dart';
import 'activity_schedule_fields.dart';

class ActivityScheduleEditor extends StatelessWidget {
  const ActivityScheduleEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ActivityScheduleDraft value;
  final ValueChanged<ActivityScheduleDraft> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        icon: const Icon(Icons.schedule),
        label: Text(
          context.lang.dashboardStartAt(
            TimeOfDay(
              hour: value.startMinute ~/ 60,
              minute: value.startMinute % 60,
            ).format(context),
          ),
        ),
        onPressed: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: value.startMinute ~/ 60,
              minute: value.startMinute % 60,
            ),
          );
          if (time != null) {
            onChanged(
              value.copyWith(startMinute: time.hour * 60 + time.minute),
            );
          }
        },
      ),
      TextButton.icon(
        icon: const Icon(Icons.event),
        label: Text(
          context.lang.activityScheduleFrom(
            DateFormat.yMd(context.lang.localeName).format(value.validFrom),
          ),
        ),
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: value.validFrom,
            firstDate: DateTime(2000),
            lastDate: clock.now().add(const Duration(days: 3650)),
          );
          if (date != null) onChanged(value.copyWith(validFrom: date));
        },
      ),
      ActivityScheduleFields(
        weekdays: value.weekdays,
        onDaysChanged: (days) => onChanged(value.copyWith(weekdays: days)),
        mode: value.confirmationMode,
        onModeChanged: (mode) =>
            onChanged(value.copyWith(confirmationMode: mode)),
        previousDayMinute: value.previousDayMinute,
        onPreviousDayMinuteChanged: (minute) =>
            onChanged(value.copyWith(previousDayMinute: minute)),
        validUntil: value.validUntil,
        onUntilChanged: (date) => onChanged(
          value.copyWith(validUntil: date, clearUntil: date == null),
        ),
      ),
    ],
  );
}
