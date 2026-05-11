import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../meals/data/providers/meal_ingredients_list_provider.dart';

class NutrientSummaryChart extends StatelessWidget {
  final Macronutrients macros;

  const NutrientSummaryChart({super.key, required this.macros});

  @override
  Widget build(BuildContext context) {
    final carbs = macros.carbsTotal;
    final fat = macros.fatTotal;
    final protein = macros.proteinTotal;
    final fiber = macros.fiberTotal;

    final total = carbs + protein + fat + fiber;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    final nutrients = [
      _Nutrient('Węglowodany', carbs, Colors.blue),
      _Nutrient('Białko', protein, Colors.green),
      _Nutrient('Tłuszcz', fat, Colors.orange),
      _Nutrient('Błonnik', fiber, Colors.purple),
    ];

    final sections = nutrients
        .map(
          (n) => PieChartSectionData(
            value: n.value.toDouble(),
            color: n.color,
            showTitle: false,
            radius: 35,
          ),
        )
        .toList();

    final legendItems = nutrients.map((n) {
      final pct = total == 0 ? 0 : n.value / total * 100;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '${n.label}: ${n.value.toStringAsFixed(0)}g (${pct.toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 14),
        ),
      );
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Podział makroskładników',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 20,
                      sectionsSpace: 5,
                      sections: sections,
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: legendItems,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Nutrient {
  final String label;
  final int value;
  final Color color;
  const _Nutrient(this.label, this.value, this.color);
}
