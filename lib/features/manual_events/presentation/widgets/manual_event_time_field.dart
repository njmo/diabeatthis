import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/date_time_picker.dart';

class ManualEventTimeField extends StatelessWidget {
  const ManualEventTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final String? label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.schedule),
    label: Text(
      '${label ?? context.lang.manualEventTime}: ${DateFormat('dd.MM.yyyy HH:mm').format(value)}',
    ),
    onPressed: () async {
      final selected = await showDateTimePicker(
        context: context,
        initialDate: value,
        lastDate: clock.now(),
      );
      if (selected != null && context.mounted) onChanged(selected);
    },
  );
}
