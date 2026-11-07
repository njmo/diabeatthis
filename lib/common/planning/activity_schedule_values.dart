import '../../features/activity/data/drafts/activity_schedule_draft.dart';

Map<String, dynamic> activityScheduleValues(
  ActivityScheduleDraft draft,
  int? duration,
) => {
  'weekdays': draft.weekdays.toList()..sort(),
  'startMinute': draft.startMinute,
  'durationMinutes': duration,
  'confirmationMode': draft.confirmationMode,
  'previousDayMinute': draft.previousDayMinute,
  'validFrom': draft.validFrom.millisecondsSinceEpoch,
  'validUntil': draft.validUntil?.millisecondsSinceEpoch,
};

ActivityScheduleDraft activityScheduleFromValues(Map values) =>
    ActivityScheduleDraft(
      weekdays: (values['weekdays'] as List).cast<int>().toSet(),
      startMinute: values['startMinute'] as int,
      confirmationMode: values['confirmationMode'] as String,
      previousDayMinute: values['previousDayMinute'] as int,
      validFrom: DateTime.fromMillisecondsSinceEpoch(
        values['validFrom'] as int,
      ),
      validUntil: values['validUntil'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(values['validUntil'] as int),
    );

bool activityScheduleIsValid(
  ActivityScheduleDraft draft, {
  int? duration,
  int? maximumDuration,
  bool cloud = false,
}) {
  final now = DateTime.now();
  return draft.weekdays.isNotEmpty &&
      draft.weekdays.length <= 7 &&
      draft.weekdays.every((d) => d >= 1 && d <= 7) &&
      draft.startMinute >= 0 &&
      draft.startMinute < 1440 &&
      draft.previousDayMinute >= 0 &&
      draft.previousDayMinute < 1440 &&
      [
        'before',
        'previous_day',
        'automatic',
      ].contains(draft.confirmationMode) &&
      (duration == null ||
          duration > 0 &&
              (maximumDuration == null || duration <= maximumDuration)) &&
      (draft.validUntil == null ||
          !draft.validUntil!.isBefore(draft.validFrom)) &&
      (!cloud ||
          draft.validFrom.millisecondsSinceEpoch > 0 &&
              !draft.validFrom.isAfter(now.add(const Duration(days: 366))) &&
              (draft.validUntil == null ||
                  !draft.validUntil!.isAfter(
                    now.add(const Duration(days: 732)),
                  )));
}
