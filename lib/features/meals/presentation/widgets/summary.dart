import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/ingredient_amount_calculator.dart';
import '../../../../common/widgets/nutrition_metric_tile.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../utils/meal_ingredient_portion_formatters.dart';
import 'ingredient_amount_result.dart';

class AddIngredientSummary extends ConsumerWidget {
  const AddIngredientSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mealIngredientsDraftProvider);
    final storedPortionAmount = draft.shouldLoadStoredPortionAmount
        ? ref.watch(
            gramsPerPortionProvider(
              draft.ingredient,
              draft.ingredientPortion.portion,
            ),
          )
        : null;
    final gramsPerPortion = resolveIngredientGramsPerPortion(
      kind: draft.amountKind,
      portionGrams: draft.ingredientPortion.amount,
      storedGramsPerPortion: storedPortionAmount?.maybeWhen(
        data: (value) => value,
        orElse: () => null,
      ),
    );
    final isLoadingPortionAmount = storedPortionAmount?.isLoading ?? false;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AddIngredientSummaryContent(
        draft: draft,
        gramsPerPortion: gramsPerPortion,
        isLoadingPortionAmount: isLoadingPortionAmount,
      ),
    );
  }
}

class AddIngredientSummaryContent extends StatelessWidget {
  final MealIngredientsDraft draft;
  final double? gramsPerPortion;
  final bool isLoadingPortionAmount;
  final bool inline;

  const AddIngredientSummaryContent({
    required this.draft,
    required this.gramsPerPortion,
    required this.isLoadingPortionAmount,
    this.inline = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final colorScheme = Theme.of(context).colorScheme;
    final amount = draft.amount;
    final amountLabel = draft.usesGramAmount
        ? '${amount.formattedAmount} g'
        : '${amount.formattedAmount} ${unitLabelForAmount(amount, draft.portionCountUnitLabel)}';
    final portionDescription = draft.usesGramAmount
        ? lang.addIngredientAddedInGrams
        : draft.portionDescription(
            portionAmount: gramsPerPortion,
            isLoading: isLoadingPortionAmount,
          );
    final totalGrams = calculateIngredientTotalGrams(
      amount: amount,
      kind: draft.amountKind,
      gramsPerPortion: gramsPerPortion,
    );
    final totalGramsLabel = isLoadingPortionAmount
        ? lang.commonLoading
        : totalGrams == null
        ? lang.amountMissingPortionWeight
        : '${totalGrams.formattedAmount} g';
    final netCarbsLabel = isLoadingPortionAmount
        ? lang.commonLoading
        : totalGrams == null
        ? '-'
        : '+${_netCarbs(totalGrams, draft).ceil()} g';
    final wbtKcalPer100g =
        draft.ingredient.wbtKcalPer100g ??
        (draft.ingredient.proteinPer100g * 4 + draft.ingredient.fatPer100g * 9);
    final extendedCarbsLabel = isLoadingPortionAmount
        ? lang.commonLoading
        : totalGrams == null
        ? '-'
        : '+${const WbtExtendedCarbsCalculator().calculateFromKcal(wbtKcalPer100g * totalGrams / 100).grams} g';

    if (inline) {
      return IngredientAmountResult(
        totalGramsLabel: draft.usesGramAmount || draft.ingredient.isReference
            ? null
            : totalGramsLabel,
        carbsLabel: netCarbsLabel,
        extendedCarbsLabel: extendedCarbsLabel,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!inline) ...[
              SummaryHeader(
                title: draft.ingredient.name,
                subtitle: portionDescription,
              ),
              const SizedBox(height: 16),
            ],
            SummaryMetricGrid(
              amountLabel: amountLabel,
              portionWeightTitle: draft.usesGramAmount
                  ? lang.portionUnitLabel
                  : lang.addIngredientPortionWeightTitle,
              portionWeightLabel: isLoadingPortionAmount
                  ? lang.commonLoading
                  : gramsPerPortion == null
                  ? '-'
                  : '${gramsPerPortion!.formattedAmount} ${draft.portionWeightUnitLabel}',
              totalGramsLabel: totalGramsLabel,
              carbsLabel: netCarbsLabel,
              extendedCarbsLabel: extendedCarbsLabel,
            ),
          ],
        ),
      ),
    );
  }

  double _netCarbs(double totalGrams, MealIngredientsDraft draft) {
    return calculateNetCarbs(
      carbs: draft.ingredient.carbsPer100g * totalGrams / 100,
      fiber: draft.ingredient.fiberPer100g * totalGrams / 100,
      labelMode: draft.ingredient.carbsLabelMode,
    );
  }
}

class SummaryHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SummaryHeader({required this.title, required this.subtitle, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          child: const Icon(Icons.restaurant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SummaryMetricGrid extends StatelessWidget {
  final String amountLabel;
  final String portionWeightTitle;
  final String portionWeightLabel;
  final String totalGramsLabel;
  final String carbsLabel;
  final String extendedCarbsLabel;

  const SummaryMetricGrid({
    required this.amountLabel,
    required this.portionWeightTitle,
    required this.portionWeightLabel,
    required this.totalGramsLabel,
    required this.carbsLabel,
    required this.extendedCarbsLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: NutritionMetricTile(
                icon: Icons.format_list_numbered,
                label: lang.addIngredientAmountTitle,
                value: amountLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NutritionMetricTile(
                icon: Icons.scale_outlined,
                label: portionWeightTitle,
                value: portionWeightLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        NutritionMetricTile(
          icon: Icons.calculate_outlined,
          label: lang.mealTotalMassLabel,
          value: totalGramsLabel,
          emphasized: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NutritionMetricTile(
                icon: Icons.grain,
                label: lang.mealCarbsLabel,
                value: carbsLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NutritionMetricTile(
                icon: Icons.schedule_outlined,
                label: 'eCarbs',
                value: extendedCarbsLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
