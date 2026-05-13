import 'package:flutter/material.dart';

import '../../../../../core/domain/model/ingredient.dart';

class IngredientListItem extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;

  const IngredientListItem({
    super.key,
    required this.ingredient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IngredientListItemHeader(ingredient: ingredient),
              const SizedBox(height: 12),
              _IngredientMacroChips(ingredient: ingredient),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientListItemHeader extends StatelessWidget {
  final Ingredient ingredient;

  const _IngredientListItemHeader({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ingredient.name, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(ingredient.brand ?? 'Bez marki', style: textTheme.bodySmall),
            ],
          ),
        ),
        if (ingredient.isReference) const _ReferenceBadge(),
      ],
    );
  }
}

class _ReferenceBadge extends StatelessWidget {
  const _ReferenceBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 15,
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(width: 5),
            Text('Ref.', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _IngredientMacroChips extends StatelessWidget {
  final Ingredient ingredient;

  const _IngredientMacroChips({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _MetricChip(
          icon: Icons.local_fire_department_outlined,
          label: '${_formatNumber(ingredient.kcalPer100g)} kcal',
        ),
        _MetricChip(
          icon: Icons.grain,
          label: 'W ${_formatNumber(ingredient.carbsPer100g)} g',
        ),
        _MetricChip(
          icon: Icons.opacity,
          label: 'T ${_formatNumber(ingredient.fatPer100g)} g',
        ),
        _MetricChip(
          icon: Icons.fitness_center,
          label: 'B ${_formatNumber(ingredient.proteinPer100g)} g',
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colors.primary),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

String _formatNumber(double? value) {
  if (value == null) {
    return '-';
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
