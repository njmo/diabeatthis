import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/ingredient_amount_calculator.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../utils/meal_ingredient_portion_formatters.dart';

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
      usesGramAmount: draft.usesGramAmount,
      isReference: draft.ingredient.isReference,
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

  const AddIngredientSummaryContent({
    required this.draft,
    required this.gramsPerPortion,
    required this.isLoadingPortionAmount,
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
      usesGramAmount: draft.usesGramAmount,
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
            SummaryHeader(
              title: draft.ingredient.name,
              subtitle: portionDescription,
            ),
            const SizedBox(height: 16),
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
              child: SummaryMetricTile(
                icon: Icons.format_list_numbered,
                label: lang.addIngredientAmountTitle,
                value: amountLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryMetricTile(
                icon: Icons.scale_outlined,
                label: portionWeightTitle,
                value: portionWeightLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SummaryMetricTile(
          icon: Icons.calculate_outlined,
          label: lang.mealTotalMassLabel,
          value: totalGramsLabel,
          emphasized: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SummaryMetricTile(
                icon: Icons.grain,
                label: lang.mealCarbsLabel,
                value: carbsLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryMetricTile(
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

class SummaryMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  const SummaryMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              icon,
              color: emphasized
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: emphasized
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: textTheme.titleMedium?.copyWith(
                      color: emphasized ? colorScheme.onPrimaryContainer : null,
                      fontWeight: emphasized ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
