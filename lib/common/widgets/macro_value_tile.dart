import 'package:flutter/material.dart';

import 'nutrition_value_tile.dart';

/// A macro value using the shared nutrition tile presentation.
class MacroValueTile extends StatelessWidget {
  const MacroValueTile({
    super.key,
    required this.label,
    required this.value,
    this.accentColor,
    this.compact = false,
  });
  final String label;
  final String value;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) => NutritionValueTile(
    label: label,
    value: value,
    accentColor: accentColor,
    compact: compact,
  );
}
