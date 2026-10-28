import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/date_time_picker.dart';

class ActivityLogTimeField extends StatelessWidget {
  const ActivityLogTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.schedule),
    label: Text(
      '$label: ${DateFormat.yMd(context.lang.localeName).add_Hm().format(value)}',
    ),
    onPressed: !enabled
        ? null
        : () async {
            final now = clock.now();
            final selected = await showDateTimePicker(
              context: context,
              initialDate: value.isAfter(now) ? now : value,
              lastDate: now,
            );
            if (selected != null && context.mounted) onChanged(selected);
          },
  );
}
