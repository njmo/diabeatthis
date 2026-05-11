import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../dashboard/presentation/widgets/nutrient_summary_chart.dart';
import '../../../data/models/meal_details_data.dart';
import '../../../data/providers/meal_ingredients_list_provider.dart';
import '../../models/meal_metric_view_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';
import 'meal_metric_components.dart';

class MealNutritionAnalysisSection extends StatelessWidget {
  final MealDetailsData details;

  const MealNutritionAnalysisSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final snapshot = details.preferredSummarySnapshot;
    final macros = Macronutrients(
      carbsTotal: snapshot?.totalCarbsG.round() ?? 0,
      fatTotal: snapshot?.totalFatG.round() ?? 0,
      fiberTotal: snapshot?.totalFiberG.round() ?? 0,
      proteinTotal: snapshot?.totalProteinG.round() ?? 0,
    );

    return MealSectionTile(
      title: 'Analiza żywieniowa',
      initiallyExpanded: true,
      children: [
        MealNutritionMacroSummary(
          snapshot: snapshot,
          hasAddOn: details.hasAddOn,
          addOnNetCarbsG: details.addOnNetCarbsG,
        ),
        const SizedBox(height: 12),
        for (final ingredient in details.ingredients)
          MealIngredientTile(ingredient: ingredient),
        const SizedBox(height: 12),
        NutrientSummaryChart(macros: macros),
        const SizedBox(height: 8),
        MealContributionBreakdown(details: details),
      ],
    );
  }
}

class MealNutritionMacroSummary extends StatelessWidget {
  final MealSnapshotDetailsData? snapshot;
  final bool hasAddOn;
  final double addOnNetCarbsG;

  const MealNutritionMacroSummary({
    super.key,
    required this.snapshot,
    required this.hasAddOn,
    required this.addOnNetCarbsG,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;

    return Column(
      children: [
        MealMetricGrid(
          metrics: [
            MealMetricTileData(
              icon: Icons.grain,
              label: 'Węglowodany',
              value: formatGrams(snapshot?.totalCarbsG),
            ),
            MealMetricTileData(
              icon: Icons.opacity,
              label: 'Tłuszcz',
              value: formatGrams(snapshot?.totalFatG),
            ),
            MealMetricTileData(
              icon: Icons.fitness_center,
              label: 'Białko',
              value: formatGrams(snapshot?.totalProteinG),
            ),
            MealMetricTileData(
              icon: Icons.eco_outlined,
              label: 'Błonnik',
              value: formatGrams(snapshot?.totalFiberG),
            ),
            if (hasAddOn)
              MealMetricTileData(
                icon: Icons.add_circle_outline,
                label: 'Węgle z dokładki',
                value: formatSignedGrams(addOnNetCarbsG),
              ),
          ],
        ),
        const SizedBox(height: 12),
        MealCompactMetricBar(
          metrics: [
            MealCompactMetricData(
              label: 'Kalorie',
              value: formatSnapshotValue(snapshot?.totalCaloriesKcal, 'kcal'),
            ),
            MealCompactMetricData(
              label: 'Netto',
              value: formatGrams(snapshot?.totalNetCarbsG),
            ),
            MealCompactMetricData(
              label: 'WBT',
              value: formatSnapshotValue(snapshot?.wbtKcal, 'kcal'),
            ),
            MealCompactMetricData(
              label: 'Masa',
              value: formatGrams(snapshot?.totalGrams),
            ),
          ],
        ),
      ],
    );
  }
}

class MealIngredientTile extends StatelessWidget {
  final MealIngredientDetailsData ingredient;

  const MealIngredientTile({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canOpenIngredient = !ingredient.usesHistoricalNutrition;

    return ExpansionTile(
      leading: Icon(
        ingredient.usesHistoricalNutrition
            ? Icons.warning_amber
            : Icons.restaurant,
        color: ingredient.usesHistoricalNutrition
            ? scheme.error
            : scheme.primary,
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(ingredient.ingredientName),
          if (ingredient.isExtra) const MealSmallBadge(label: 'dodatkowy'),
          if (ingredient.usesHistoricalNutrition)
            const MealSmallBadge(label: 'historyczne wartości'),
        ],
      ),
      subtitle: Text(
        [
          ingredient.isExtra ? 'dodane po posiłku' : 'planowany',
          'porcja ${ingredient.portionLabel}',
          'plan ${formatNumber(ingredient.plannedAmount)}',
          'zjedzono ${formatNumber(ingredient.effectiveConsumedAmount)}',
          formatGrams(ingredient.consumedTotalGrams),
        ].join(' • '),
      ),
      trailing: canOpenIngredient
          ? IconButton(
              tooltip: 'Otwórz składnik',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => context.router.push(
                IngredientRoute(ingredientId: ingredient.ingredientId),
              ),
            )
          : Tooltip(
              message:
                  'Ten posiłek używa historycznych wartości; link do aktualnego składnika jest nieaktywny.',
              child: Icon(Icons.link_off, color: scheme.error),
            ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        MealInfoRow(
          label: 'Typ wpisu',
          value: mealEntryTypeLabel(ingredient.entryType),
        ),
        MealInfoRow(label: 'Porcja', value: ingredient.portionLabel),
        MealInfoRow(
          label: 'Ilość planowana',
          value: formatNumber(ingredient.plannedAmount),
        ),
        MealInfoRow(
          label: 'Ilość zjedzona',
          value: formatNumber(ingredient.effectiveConsumedAmount),
        ),
        MealInfoRow(
          label: 'Pewność ilości',
          value: formatConfidence(ingredient.quantityConfidence),
        ),
        MealInfoRow(
          label: 'Pewność zjedzenia',
          value: formatConfidence(ingredient.consumedConfidence),
        ),
        MealInfoRow(
          label: 'Planowana masa',
          value: formatGrams(ingredient.plannedTotalGrams),
        ),
        MealInfoRow(
          label: 'Zjedzona masa',
          value: formatGrams(ingredient.consumedTotalGrams),
        ),
        MealInfoRow(
          label: 'Przygotowanie',
          value: fallbackText(ingredient.prepMethod),
        ),
        MealInfoRow(label: 'Notatki', value: fallbackText(ingredient.notes)),
        const SizedBox(height: 8),
        NutritionComparisonTable(ingredient: ingredient),
      ],
    );
  }
}

class NutritionComparisonTable extends StatelessWidget {
  final MealIngredientDetailsData ingredient;

  const NutritionComparisonTable({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('Wartość')),
          DataColumn(label: Text('Plan')),
          DataColumn(label: Text('Zjedzone')),
          DataColumn(label: Text('Aktualne')),
        ],
        rows: [
          _nutritionRow(
            'Węglowodany/100g',
            ingredient.plannedNutrition.carbsPer100g,
            ingredient.consumedNutrition.carbsPer100g,
            ingredient.currentNutrition.carbsPer100g,
            'g',
          ),
          _nutritionRow(
            'Tłuszcz/100g',
            ingredient.plannedNutrition.fatPer100g,
            ingredient.consumedNutrition.fatPer100g,
            ingredient.currentNutrition.fatPer100g,
            'g',
          ),
          _nutritionRow(
            'Błonnik/100g',
            ingredient.plannedNutrition.fiberPer100g,
            ingredient.consumedNutrition.fiberPer100g,
            ingredient.currentNutrition.fiberPer100g,
            'g',
          ),
          _nutritionRow(
            'Białko/100g',
            ingredient.plannedNutrition.proteinPer100g,
            ingredient.consumedNutrition.proteinPer100g,
            ingredient.currentNutrition.proteinPer100g,
            'g',
          ),
          _nutritionRow(
            'Pewność',
            ingredient.plannedNutrition.nutritionConfidence,
            ingredient.consumedNutrition.nutritionConfidence,
            ingredient.currentNutrition.nutritionConfidence,
            '',
          ),
        ],
      ),
    );
  }

  DataRow _nutritionRow(
    String label,
    double planned,
    double consumed,
    double current,
    String unit,
  ) {
    return DataRow(
      cells: [
        DataCell(Text(label)),
        DataCell(Text(formatNutritionValue(planned, unit))),
        DataCell(Text(formatNutritionValue(consumed, unit))),
        DataCell(Text(formatNutritionValue(current, unit))),
      ],
    );
  }
}

class MealContributionBreakdown extends StatelessWidget {
  final MealDetailsData details;

  const MealContributionBreakdown({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final totalCarbs = details.ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedCarbsContribution,
    );
    final totalFat = details.ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedFatContribution,
    );
    final totalCalories = details.ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedCaloriesContribution,
    );

    return Column(
      children: [
        for (final ingredient in details.ingredients)
          MealInfoRow(
            label: ingredient.ingredientName,
            value:
                'węgl. ${formatShare(ingredient.consumedCarbsContribution, totalCarbs)} • tł. ${formatShare(ingredient.consumedFatContribution, totalFat)} • kcal ${formatShare(ingredient.consumedCaloriesContribution, totalCalories)} • WBT ${formatNumber(ingredient.consumedWbtKcalContribution)} kcal',
          ),
      ],
    );
  }
}
