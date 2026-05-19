import 'package:flutter/material.dart';

class DataSourceDropdown<T extends Object> extends StatelessWidget {
  const DataSourceDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final source in values)
          DropdownMenuItem(value: source, child: Text(labelFor(source))),
      ],
      onChanged: (value) {
        if (value == null) return;
        if (value == this.value) return;
        onChanged(value);
      },
    );
  }
}
