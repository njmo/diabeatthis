import 'package:flutter/material.dart';

import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/models/ingredient_details_data.dart';
import 'ingredient_identity_text.dart';

class IngredientDetailsView extends StatelessWidget {
  final IngredientDetailsData data;

  const IngredientDetailsView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final ingredient = data.ingredient;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IngredientHeader(ingredient: ingredient),
        const SizedBox(height: 12),
        _MacroGrid(ingredient: ingredient),
        const SizedBox(height: 12),
        _EnergySummary(ingredient: ingredient),
      ],
    );
  }
}

class _IngredientHeader extends StatelessWidget {
  final Ingredient ingredient;

  const _IngredientHeader({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IngredientIdentityText(
                        name: ingredient.name,
                        brand: ingredient.brand,
                        nameStyle: Theme.of(context).textTheme.headlineSmall,
                        brandStyle: Theme.of(context).textTheme.bodyMedium,
                        spacing: 4,
                      ),
                    ],
                  ),
                ),
                if (ingredient.isReference)
                  const _StatusPill(
                    icon: Icons.restaurant_menu,
                    label: 'Referencyjny',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  icon: Icons.verified_outlined,
                  label: ConfidenceLevelX.fromDouble01(
                    ingredient.nutritionConfidence,
                  ).label,
                ),
                _StatusPill(
                  icon: Icons.monitor_heart_outlined,
                  label: 'IG ${ingredient.ig ?? '-'}',
                ),
                _StatusPill(
                  icon: Icons.local_fire_department_outlined,
                  label: '${_formatNumber(ingredient.kcalPer100g)} kcal',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroGrid extends StatelessWidget {
  final Ingredient ingredient;

  const _MacroGrid({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          padding: EdgeInsets.zero,
          childAspectRatio: columns == 4 ? 1.65 : 1.85,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MacroTile(
              label: 'Węglowodany',
              value: ingredient.carbsPer100g,
              icon: Icons.grain,
            ),
            _MacroTile(
              label: 'Tłuszcz',
              value: ingredient.fatPer100g,
              icon: Icons.opacity,
            ),
            _MacroTile(
              label: 'Białko',
              value: ingredient.proteinPer100g,
              icon: Icons.fitness_center,
            ),
            _MacroTile(
              label: 'Błonnik',
              value: ingredient.fiberPer100g,
              icon: Icons.eco_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;

  const _MacroTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: _formatNumber(value),
                    children: [
                      TextSpan(
                        text: ' g / 100 g',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergySummary extends StatelessWidget {
  final Ingredient ingredient;

  const _EnergySummary({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _CompactMetric(
                label: 'Kalorie',
                value: '${_formatNumber(ingredient.kcalPer100g)} kcal',
              ),
            ),
            const _MetricDivider(),
            Expanded(
              child: _CompactMetric(
                label: 'Net',
                value: '${_formatNumber(ingredient.netKcalPer100g)} kcal',
              ),
            ),
            const _MetricDivider(),
            Expanded(
              child: _CompactMetric(
                label: 'WBT',
                value: '${_formatNumber(ingredient.wbtKcalPer100g)} kcal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CompactMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.onSecondaryContainer),
            const SizedBox(width: 6),
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
  return value.toStringAsFixed(2);
}
