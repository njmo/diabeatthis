import 'package:flutter/material.dart';

class MealSummaryConfidenceSelector extends StatelessWidget {
  const MealSummaryConfidenceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          selected: _isSelected(0.5),
          label: const Text('Na oko'),
          avatar: const Icon(Icons.visibility_outlined, size: 18),
          onSelected: (_) => onChanged(0.5),
        ),
        ChoiceChip(
          selected: _isSelected(0.75),
          label: const Text('Prawie pewne'),
          avatar: const Icon(Icons.thumbs_up_down_outlined, size: 18),
          onSelected: (_) => onChanged(0.75),
        ),
        ChoiceChip(
          selected: _isSelected(1),
          label: const Text('Pewne'),
          avatar: const Icon(Icons.check_circle_outline, size: 18),
          onSelected: (_) => onChanged(1),
        ),
      ],
    );
  }

  bool _isSelected(double option) {
    return (value - option).abs() < 0.01;
  }
}
