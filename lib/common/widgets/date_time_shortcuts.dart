import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../l10n/language.dart';

class DateTimeShortcuts extends StatelessWidget {
  const DateTimeShortcuts({super.key, required this.onSelected});

  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ActionChip(
          label: Text(context.lang.plannedTimeNow),
          onPressed: () => onSelected(clock.now()),
        ),
        ActionChip(
          label: Text(context.lang.plannedTimeIn15Minutes),
          onPressed: () =>
              onSelected(clock.now().add(const Duration(minutes: 15))),
        ),
        ActionChip(
          label: Text(context.lang.plannedTimeIn45Minutes),
          onPressed: () =>
              onSelected(clock.now().add(const Duration(minutes: 45))),
        ),
      ],
    );
  }
}
