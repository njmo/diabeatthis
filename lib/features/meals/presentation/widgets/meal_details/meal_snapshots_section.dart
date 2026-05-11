import 'package:flutter/material.dart';

import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealSnapshotsSection extends StatelessWidget {
  final MealDetailsData details;

  const MealSnapshotsSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final rows = _snapshotRows(details);

    return MealSectionTile(
      title: 'Snapshoty plan vs zjedzone',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Pole')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Zjedzone')),
              DataColumn(label: Text('Różnica')),
            ],
            rows: rows.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(row.label)),
                  DataCell(
                    Text(formatSnapshotValue(row.plannedValue, row.unit)),
                  ),
                  DataCell(
                    Text(formatSnapshotValue(row.consumedValue, row.unit)),
                  ),
                  DataCell(Text(formatSnapshotDiff(row.difference, row.unit))),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        for (final ingredient in details.ingredients.where((i) => i.isExtra))
          MealInfoRow(
            label: 'Dodatkowy składnik',
            value:
                '${ingredient.ingredientName}: ${formatNumber(ingredient.consumedTotalGrams)}g',
          ),
      ],
    );
  }
}

List<MealSnapshotComparisonRowData> _snapshotRows(MealDetailsData details) {
  final planned = details.plannedSnapshot;
  final consumed = details.consumedSnapshot;
  return [
    MealSnapshotComparisonRowData(
      label: 'Węglowodany',
      plannedValue: planned?.totalCarbsG,
      consumedValue: consumed?.totalCarbsG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: 'Tłuszcz',
      plannedValue: planned?.totalFatG,
      consumedValue: consumed?.totalFatG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: 'Białko',
      plannedValue: planned?.totalProteinG,
      consumedValue: consumed?.totalProteinG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: 'Błonnik',
      plannedValue: planned?.totalFiberG,
      consumedValue: consumed?.totalFiberG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: 'Kalorie',
      plannedValue: planned?.totalCaloriesKcal,
      consumedValue: consumed?.totalCaloriesKcal,
      unit: 'kcal',
    ),
    MealSnapshotComparisonRowData(
      label: 'Masa całkowita',
      plannedValue: planned?.totalGrams,
      consumedValue: consumed?.totalGrams,
      unit: 'g',
    ),
  ];
}
