import 'package:flutter/material.dart';

class FamilyPlanTimeField extends StatelessWidget {
  const FamilyPlanTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}',
    ),
    trailing: const Icon(Icons.edit_calendar_outlined),
    onTap: () async {
      final now = DateTime.now();
      final day = await showDatePicker(
        context: context,
        initialDate: value.isBefore(now) ? now : value,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365)),
      );
      if (day == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(value),
      );
      if (time != null) {
        onChanged(
          DateTime(day.year, day.month, day.day, time.hour, time.minute),
        );
      }
    },
  );
}
