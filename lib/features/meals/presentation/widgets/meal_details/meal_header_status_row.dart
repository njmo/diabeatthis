import 'package:flutter/material.dart';

import 'header_status_chip.dart';

class MealHeaderStatusRow extends StatelessWidget {
  final List<HeaderStatusChip> chips;

  const MealHeaderStatusRow({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}
