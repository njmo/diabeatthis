import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';

class DayDateSelector extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final ValueChanged<DateTime?> onSelected;
  final List<Widget> actions;
  const DayDateSelector({
    super.key,
    required this.date,
    required this.today,
    required this.onSelected,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final isToday = DateUtils.isSameDay(date, today);
    final formatted = DateFormat('dd.MM.yyyy').format(date);
    final label = isToday ? lang.daySelectedToday(formatted) : formatted;
    final compactButtonStyle = IconButton.styleFrom(
      minimumSize: const Size(32, 44),
      padding: const EdgeInsets.all(4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          IconButton(
            style: compactButtonStyle,
            tooltip: lang.dayPreviousDate,
            onPressed: date.isAfter(DateTime(1970))
                ? () =>
                      onSelected(DateTime(date.year, date.month, date.day - 1))
                : null,
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
            style: compactButtonStyle,
            tooltip: lang.dayNextDate,
            onPressed: isToday
                ? null
                : () {
                    final next = DateTime(date.year, date.month, date.day + 1);
                    onSelected(DateUtils.isSameDay(next, today) ? null : next);
                  },
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
          if (!isToday)
            IconButton(
              style: compactButtonStyle,
              tooltip: lang.dayBackToToday,
              onPressed: () => onSelected(null),
              icon: const Icon(Icons.today, size: 18),
            ),
          for (final action in actions)
            SizedBox(width: 40, height: 44, child: action),
        ],
      ),
    );
  }
}
