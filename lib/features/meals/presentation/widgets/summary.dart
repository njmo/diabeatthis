import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger/logger.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../data/providers/meal_draft_provider.dart';

class AddIngredientSummary extends ConsumerWidget with Logging{
  const AddIngredientSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.read(mealIngredientsDraftProvider);

    final portion = draft.ingredientPortion.portion;
    final gramsPerPortion = draft.ingredientPortion.portion.map(
      empty: (_) => draft.ingredient.isReference ? 100 : 1,
      draft: (p) => draft.ingredientPortion.amount,
      existing: (p) => draft.ingredientPortion.amount,
    );
    final portionCount = draft.amount;

    final portionName = portion.map(
      draft: (e) => e.unitHint,
      existing: (e) => e.unitHint,
      empty: (_) => draft.ingredient.isReference ? 'porcja' : 'g',
    );

    final totalGrams = portionCount * gramsPerPortion;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  children: [
                    _SummaryRow(
                      icon: Icons.restaurant,
                      label: 'Składnik',
                      value: draft.ingredient.name,
                    ),

                    const Divider(height: 15),

                    _SummaryRow(
                      icon: Icons.straighten,
                      label: 'Porcja',
                      value: portionName,
                    ),

                    const Divider(height: 15),

                    _SummaryRow(
                      icon: Icons.format_list_numbered,
                      label: 'Ilość porcji',
                      value: '$portionCount',
                    ),

                    const Divider(height: 15),

                    _SummaryRow(
                      icon: Icons.scale,
                      label: 'Waga porcji',
                      value: '$gramsPerPortion g',
                    ),

                    const Divider(height: 15),

                    _SummaryRow(
                      icon: Icons.calculate,
                      label: 'Łącznie',
                      value: '$totalGrams g',
                      isEmphasized: true,
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

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isEmphasized;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: isEmphasized
                    ? textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )
                    : textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}