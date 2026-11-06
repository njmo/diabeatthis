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
  });
  final double iob;
  final double cob;
  final bool hasIob;
  final bool hasCob;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: NutritionMetricTile(
          icon: Icons.water_drop,
          label: context.lang.dashboardIobLabel,
          value: hasIob ? '${iob.toStringAsFixed(2)} U' : '—',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: NutritionMetricTile(
          leading: const CarbohydrateIcon(),
          label: context.lang.dashboardCobLabel,
          value: hasCob ? '${cob.toStringAsFixed(2)} g' : '—',
        ),
      ),
    ],
  );
}
