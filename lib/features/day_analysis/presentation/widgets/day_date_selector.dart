import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';

class DayDateSelector extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final ValueChanged<DateTime?> onSelected;
  const DayDateSelector({
    super.key,
    required this.date,
    required this.today,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final isToday = DateUtils.isSameDay(date, today);
    return Row(
      children: [
        IconButton(
          tooltip: lang.dayPreviousDate,
          onPressed: date.isAfter(DateTime(1970))
              ? () => onSelected(DateTime(date.year, date.month, date.day - 1))
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(DateFormat('dd.MM.yyyy').format(date)),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(1970),
                lastDate: today,
                currentDate: today,
                helpText: lang.daySelectDate,
              );
              if (!context.mounted || selected == null) return;
              onSelected(
                DateUtils.isSameDay(selected, today) ? null : selected,
              );
            },
          ),
        ),
        IconButton(
          tooltip: lang.dayNextDate,
          onPressed: isToday
              ? null
              : () {
                  final next = DateTime(date.year, date.month, date.day + 1);
                  onSelected(DateUtils.isSameDay(next, today) ? null : next);
                },
          icon: const Icon(Icons.chevron_right),
        ),
        if (!isToday)
          IconButton(
            tooltip: lang.dayBackToToday,
            onPressed: () => onSelected(null),
            icon: const Icon(Icons.today),
          ),
      ],
    );
  }
}
