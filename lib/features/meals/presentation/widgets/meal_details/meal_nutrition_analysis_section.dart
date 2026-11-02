import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/nutrition/meal_nutrition_totals.dart';
import '../../../../dashboard/presentation/widgets/nutrient_summary_chart.dart';
import '../../../data/models/meal_details_data.dart';
import '../../../data/providers/meal_ingredients_list_provider.dart';
import '../../models/meal_metric_view_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';
import 'meal_metric_components.dart';

class MealNutritionAnalysisSection extends StatelessWidget {
  final MealDetailsData details;
  final bool? initiallyExpanded;
  final bool inline;
  final bool showSummary;

  const MealNutritionAnalysisSection({
    super.key,
    required this.details,
    this.initiallyExpanded,
    this.inline = false,
    this.showSummary = true,
  });

  @override
  Widget build(BuildContext context) {
    final nutrition = details.preferredNutritionTotals;
    final macros = Macronutrients(
      carbsTotal: (nutrition?.totalCarbsG ?? 0).ceil(),
      fatTotal: (nutrition?.totalFatG ?? 0).ceil(),
      fiberTotal: (nutrition?.totalFiberG ?? 0).ceil(),
      proteinTotal: (nutrition?.totalProteinG ?? 0).ceil(),
      netCarbsTotal: (nutrition?.totalNetCarbsG ?? 0).ceil(),
    );

    return MealSectionTile(
      collapsible: !inline,
      title: context.lang.mealNutritionTitle,
      initiallyExpanded: initiallyExpanded ?? !details.meal.isEaten,
      children: [
        if (showSummary)
          MealNutritionMacroSummary(
            nutrition: nutrition,
            hasAddOn: details.hasAddOn,
            addOnNetCarbsG: details.addOnNetCarbsG,
          ),
        const SizedBox(height: 12),
        for (final ingredient in details.ingredients)
          MealIngredientTile(
            ingredient: ingredient,
            usePlannedConsumptionFallback: details.meal.status != 'interrupted',
          ),
        const SizedBox(height: 12),
        NutrientSummaryChart(macros: macros),
        const SizedBox(height: 8),
        MealContributionBreakdown(details: details),
      ],
    );
  }
}

class MealNutritionMacroSummary extends StatelessWidget {
  final MealNutritionTotals? nutrition;
  final bool hasAddOn;
  final double addOnNetCarbsG;

  const MealNutritionMacroSummary({
    super.key,
    required this.nutrition,
    required this.hasAddOn,
    required this.addOnNetCarbsG,
  });

  @override
  Widget build(BuildContext context) {
    final nutrition = this.nutrition;

    return Column(
      children: [
        MealMetricGrid(
          metrics: [
            MealMetricTileData(
              icon: Icons.grain,
              label: context.lang.mealCarbsLabel,
              value: formatGrams(nutrition?.totalCarbsG),
            ),
            MealMetricTileData(
              icon: Icons.opacity,
              label: context.lang.mealFatLabel,
              value: formatGrams(nutrition?.totalFatG),
            ),
            MealMetricTileData(
              icon: Icons.fitness_center,
              label: context.lang.mealProteinLabel,
              value: formatGrams(nutrition?.totalProteinG),
            ),
            MealMetricTileData(
              icon: Icons.eco_outlined,
              label: context.lang.mealFiberLabel,
              value: formatGrams(nutrition?.totalFiberG),
            ),
            if (hasAddOn)
              MealMetricTileData(
                icon: Icons.add_circle_outline,
                label: context.lang.mealAddOnCarbsLabel,
                value: formatSignedGrams(addOnNetCarbsG),
              ),
          ],
        ),
        const SizedBox(height: 12),
        MealCompactMetricBar(
          metrics: [
            MealCompactMetricData(
              label: context.lang.mealCaloriesLabel,
              value: formatSnapshotValue(nutrition?.totalCaloriesKcal, 'kcal'),
            ),
            MealCompactMetricData(
              label: context.lang.mealNetLabel,
              value: formatGrams(nutrition?.totalNetCarbsG),
            ),
            MealCompactMetricData(
              label: context.lang.mealWbtLabel,
              value: formatSnapshotValue(nutrition?.wbtKcal, 'kcal'),
            ),
            MealCompactMetricData(
              label: context.lang.mealMassLabel,
              value: formatGrams(nutrition?.totalGrams),
            ),
          ],
        ),
      ],
    );
  }
}

class MealIngredientTile extends StatelessWidget {
  final MealIngredientDetailsData ingredient;
  final bool usePlannedConsumptionFallback;

  const MealIngredientTile({
    super.key,
    required this.ingredient,
    this.usePlannedConsumptionFallback = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canOpenIngredient = !ingredient.usesHistoricalNutrition;
    final hasConsumedAmount =
        usePlannedConsumptionFallback || ingredient.consumedAmount != null;
    final consumedAmount = hasConsumedAmount
        ? formatNumber(ingredient.effectiveConsumedAmount)
        : '-';
    final consumedGrams = hasConsumedAmount
        ? ingredient.consumedTotalGrams
        : null;

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
          if (ingredient.isExtra)
            MealSmallBadge(label: context.lang.mealExtraBadge),
          if (ingredient.usesHistoricalNutrition)
            MealSmallBadge(label: context.lang.mealHistoricalValuesBadge),
        ],
      ),
      subtitle: Text(
        [
          ingredient.isExtra
              ? context.lang.mealAddedAfterMeal
              : context.lang.mealPlannedEntry,
          context.lang.mealPortionInline(ingredient.portionLabel),
          context.lang.mealPlanInline(formatNumber(ingredient.plannedAmount)),
          context.lang.mealConsumedInline(consumedAmount),
          formatGrams(consumedGrams),
        ].join(' • '),
      ),
      trailing: canOpenIngredient
          ? IconButton(
              tooltip: context.lang.mealOpenIngredientTooltip,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => context.router.push(
                IngredientRoute(ingredientId: ingredient.ingredientId),
              ),
            )
          : Tooltip(
              message: context.lang.mealHistoricalIngredientTooltip,
              child: Icon(Icons.link_off, color: scheme.error),
            ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        MealInfoRow(
          label: context.lang.mealEntryTypeLabel,
          value: mealEntryTypeLabel(ingredient.entryType),
        ),
        MealInfoRow(
          label: context.lang.mealPortionLabel,
          value: ingredient.portionLabel,
        ),
        MealInfoRow(
          label: context.lang.mealPlannedAmountLabel,
          value: formatNumber(ingredient.plannedAmount),
        ),
        MealInfoRow(
          label: context.lang.mealConsumedAmountLabel,
          value: consumedAmount,
        ),
        MealInfoRow(
          label: context.lang.mealQuantityConfidenceLabel,
          value: formatConfidence(ingredient.quantityConfidence),
        ),
        MealInfoRow(
          label: context.lang.mealConsumedConfidenceLabel,
          value: formatConfidence(ingredient.consumedConfidence),
        ),
        MealInfoRow(
          label: context.lang.mealPlannedMassLabel,
          value: formatGrams(ingredient.plannedTotalGrams),
        ),
        MealInfoRow(
          label: context.lang.mealConsumedMassLabel,
          value: formatGrams(consumedGrams),
        ),
        MealInfoRow(
          label: context.lang.mealPrepMethodLabel,
          value: fallbackText(ingredient.prepMethod),
        ),
        MealInfoRow(
          label: context.lang.mealNotesLabel,
          value: fallbackText(ingredient.notes),
        ),
        const SizedBox(height: 8),
        NutritionComparisonTable(
          ingredient: ingredient,
          hasConsumedData: hasConsumedAmount,
        ),
      ],
    );
  }
}

class NutritionComparisonTable extends StatelessWidget {
  final MealIngredientDetailsData ingredient;
  final bool hasConsumedData;

  const NutritionComparisonTable({
    super.key,
    required this.ingredient,
    this.hasConsumedData = true,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columns: [
          DataColumn(label: Text(context.lang.mealValueColumn)),
          DataColumn(label: Text(context.lang.mealSnapshotsPlanColumn)),
          DataColumn(label: Text(context.lang.mealSnapshotsConsumedColumn)),
          DataColumn(label: Text(context.lang.mealCurrentColumn)),
        ],
        rows: [
          _nutritionRow(
            context.lang.mealCarbsPer100gLabel,
            ingredient.plannedNutrition.carbsPer100g,
            ingredient.consumedNutrition.carbsPer100g,
            ingredient.currentNutrition.carbsPer100g,
            'g',
          ),
          _nutritionRow(
            context.lang.mealFatPer100gLabel,
            ingredient.plannedNutrition.fatPer100g,
            ingredient.consumedNutrition.fatPer100g,
            ingredient.currentNutrition.fatPer100g,
            'g',
          ),
          _nutritionRow(
            context.lang.mealFiberPer100gLabel,
            ingredient.plannedNutrition.fiberPer100g,
            ingredient.consumedNutrition.fiberPer100g,
            ingredient.currentNutrition.fiberPer100g,
            'g',
          ),
          _nutritionRow(
            context.lang.mealProteinPer100gLabel,
            ingredient.plannedNutrition.proteinPer100g,
            ingredient.consumedNutrition.proteinPer100g,
            ingredient.currentNutrition.proteinPer100g,
            'g',
          ),
          _nutritionRow(
            context.lang.mealConfidenceLabel,
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
        DataCell(
          Text(hasConsumedData ? formatNutritionValue(consumed, unit) : '-'),
        ),
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
    final ingredients = details.ingredients.where(
      (ingredient) =>
          details.meal.status != 'interrupted' ||
          ingredient.consumedAmount != null,
    );
    final totalCarbs = ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedCarbsContribution,
    );
    final totalFat = ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedFatContribution,
    );
    final totalCalories = ingredients.fold<double>(
      0,
      (sum, ingredient) => sum + ingredient.consumedCaloriesContribution,
    );

    return Column(
      children: [
        for (final ingredient in ingredients)
          MealInfoRow(
            label: ingredient.ingredientName,
            value: context.lang.mealNutritionContribution(
              formatShare(ingredient.consumedCarbsContribution, totalCarbs),
              formatShare(ingredient.consumedFatContribution, totalFat),
              formatShare(
                ingredient.consumedCaloriesContribution,
                totalCalories,
              ),
              formatNumber(ingredient.consumedWbtKcalContribution),
            ),
          ),
      ],
    );
  }
}
