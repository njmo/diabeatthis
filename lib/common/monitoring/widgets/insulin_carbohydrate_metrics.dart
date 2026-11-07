import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../widgets/carbohydrate_icon.dart';
import '../../widgets/nutrition_metric_tile.dart';

class InsulinCarbohydrateMetrics extends StatelessWidget {
  const InsulinCarbohydrateMetrics({
    super.key,
    required this.iob,
    required this.cob,
    this.hasIob = true,
    this.hasCob = true,
    this.iconSize = 24,
    this.iconSpacing = 10,
  });
  final double iconSize;
  final double iconSpacing;
  final double iob;
  final double cob;
  final bool hasIob;
  final bool hasCob;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: NutritionMetricTile(
            iconSize: iconSize,
            iconSpacing: iconSpacing,
            iconColor: !hasIob
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : dark
                ? const Color(0xFF80D8F7)
                : const Color(0xFF08799E),
            icon: Icons.water_drop,
            label: context.lang.dashboardIobLabel,
            value: hasIob ? '${iob.toStringAsFixed(2)} U' : '—',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NutritionMetricTile(
            iconSize: iconSize,
            iconSpacing: iconSpacing,
            iconColor: !hasCob
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : dark
                ? const Color(0xFFF3C96A)
                : const Color(0xFF986500),
            leading: const CarbohydrateIcon(),
            label: context.lang.dashboardCobLabel,
            value: hasCob ? '${cob.toStringAsFixed(2)} g' : '—',
          ),
        ),
      ],
    );
  }
}
