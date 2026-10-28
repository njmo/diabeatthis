import 'package:clock/clock.dart';
import '../../../../core/drift/database_impl.dart';

class ActivityScheduleDraft {
  ActivityScheduleDraft({
    this.weekdays = const {},
    this.startMinute = 17 * 60,
    this.confirmationMode = 'before',
    this.previousDayMinute = 19 * 60,
    DateTime? validFrom,
    this.validUntil,
  }) : validFrom =
           validFrom ??
           DateTime(clock.now().year, clock.now().month, clock.now().day);

  factory ActivityScheduleDraft.fromRule(ActivityScheduleData rule) =>
      ActivityScheduleDraft(
        weekdays: rule.weekdays.split(',').map(int.parse).toSet(),
        startMinute: rule.startMinute,
        confirmationMode: rule.confirmationMode,
        previousDayMinute: rule.previousDayMinute,
        validFrom: DateTime.fromMillisecondsSinceEpoch(rule.validFrom),
        validUntil: rule.validUntil == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(rule.validUntil!),
      );

  final Set<int> weekdays;
  final int startMinute;
  final String confirmationMode;
  final int previousDayMinute;
  final DateTime validFrom;
  final DateTime? validUntil;

  ActivityScheduleDraft copyWith({
    Set<int>? weekdays,
    int? startMinute,
    String? confirmationMode,
    int? previousDayMinute,
    DateTime? validFrom,
    DateTime? validUntil,
    bool clearUntil = false,
  }) => ActivityScheduleDraft(
    weekdays: weekdays ?? this.weekdays,
    startMinute: startMinute ?? this.startMinute,
    confirmationMode: confirmationMode ?? this.confirmationMode,
    previousDayMinute: previousDayMinute ?? this.previousDayMinute,
    validFrom: validFrom ?? this.validFrom,
    validUntil: clearUntil ? null : validUntil ?? this.validUntil,
  );
}
