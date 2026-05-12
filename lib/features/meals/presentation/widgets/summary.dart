import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final gramsPerPortion = _resolveGramsPerPortion(
      draft: draft,
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

  double? _resolveGramsPerPortion({
    required MealIngredientsDraft draft,
    required double? storedGramsPerPortion,
  }) {
    if (draft.usesGramAmount) {
      return 1;
    }
    if (draft.ingredient.isReference) {
      return 100;
    }
    if (draft.ingredientPortion.amount > 0) {
      return draft.ingredientPortion.amount;
    }
    return storedGramsPerPortion;
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
    final colorScheme = Theme.of(context).colorScheme;
    final amount = draft.amount;
    final amountLabel = draft.usesGramAmount
        ? '${amount.formattedAmount} g'
        : '${amount.formattedAmount} ${unitLabelForAmount(amount, draft.portionCountUnitLabel)}';
    final portionDescription = draft.usesGramAmount
        ? 'Dodawane w gramach'
        : draft.portionDescription(
            portionAmount: gramsPerPortion,
            isLoading: isLoadingPortionAmount,
          );
    final totalGrams = _totalGrams(amount, gramsPerPortion, draft);
    final totalGramsLabel = isLoadingPortionAmount
        ? 'Ładuję...'
        : totalGrams == null
        ? 'Brak wagi porcji'
        : '${totalGrams.formattedAmount} g';

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
                  ? 'Jednostka'
                  : 'Waga porcji',
              portionWeightLabel: isLoadingPortionAmount
                  ? 'Ładuję...'
                  : gramsPerPortion == null
                  ? '-'
                  : '${gramsPerPortion!.formattedAmount} ${draft.portionWeightUnitLabel}',
              totalGramsLabel: totalGramsLabel,
            ),
          ],
        ),
      ),
    );
  }

  double? _totalGrams(
    double amount,
    double? gramsPerPortion,
    MealIngredientsDraft draft,
  ) {
    if (draft.usesGramAmount) {
      return amount;
    }
    if (gramsPerPortion == null || gramsPerPortion <= 0) {
      return null;
    }
    return amount * gramsPerPortion;
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

  const SummaryMetricGrid({
    required this.amountLabel,
    required this.portionWeightTitle,
    required this.portionWeightLabel,
    required this.totalGramsLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SummaryMetricTile(
                icon: Icons.format_list_numbered,
                label: 'Ilość',
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
          label: 'Łącznie',
          value: totalGramsLabel,
          emphasized: true,
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
