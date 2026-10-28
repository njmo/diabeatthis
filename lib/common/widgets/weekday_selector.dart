import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/language.dart';

class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final Set<int> value;
  final ValueChanged<Set<int>> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    children: List.generate(7, (index) {
      final day = index + 1;
      return FilterChip(
        label: Text(
          DateFormat.E(context.lang.localeName).format(DateTime(2024, 1, day)),
        ),
        selected: value.contains(day),
        onSelected: (selected) =>
            onChanged(selected ? {...value, day} : ({...value}..remove(day))),
      );
    }),
  );
}
