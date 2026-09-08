import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/date_time_picker.dart';

class StressEndTimeField extends StatelessWidget {
  const StressEndTimeField({
    super.key,
    required this.startedAt,
    required this.value,
    required this.onChanged,
  });

  final DateTime startedAt;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.schedule),
    label: Text(
      '${context.lang.manualEventStressEnd}: ${DateFormat(DateUtils.isSameDay(startedAt, value) ? 'HH:mm' : 'dd.MM.yyyy HH:mm').format(value)}',
    ),
    onPressed: () async {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(value),
      );
      if (time != null && context.mounted) {
        onChanged(endTimeForStart(startedAt, time));
      }
    },
  );
}
