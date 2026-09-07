import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/models/ingredient_history_entry_data.dart';
import '../../data/models/ingredient_portion_data.dart';
import '../../data/models/ingredient_usage_data.dart';

class IngredientHistorySection extends StatelessWidget {
  final List<IngredientHistoryEntryData> history;

  const IngredientHistorySection({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.history,
          title: context.lang.ingredientMacroHistoryTitle,
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          _EmptyState(
            icon: Icons.history_toggle_off,
            label: context.lang.ingredientMacroHistoryEmpty,
          )
        else
          ...history.map((entry) => _HistoryItem(entry: entry)),
      ],
    );
  }
}

class IngredientPortionsSection extends StatelessWidget {
  final List<IngredientPortionData> portions;
  final ValueChanged<IngredientPortionData>? onEdit;

  const IngredientPortionsSection({
    super.key,
    required this.portions,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.straighten,
          title: context.lang.ingredientDefinedPortionsTitle,
        ),
        const SizedBox(height: 8),
        if (portions.isEmpty)
          _EmptyState(
            icon: Icons.straighten,
            label: context.lang.ingredientDefinedPortionsEmpty,
          )
        else
          ...portions.map((portion) {
            return _ListSurface(
              leading: Icons.scale_outlined,
              title: portion.name,
              subtitle: portion.unitHint,
              trailing: '${_formatNumber(portion.gramsPerPortion)} g',
              onTap: onEdit == null ? null : () => onEdit!(portion),
              trailingIcon: onEdit == null ? null : Icons.edit_outlined,
              trailingTooltip: context.lang.ingredientEditPortionTooltip,
            );
          }),
      ],
    );
  }
}

class IngredientMealsSection extends StatelessWidget {
  final List<IngredientUsageData> usages;

  const IngredientMealsSection({super.key, required this.usages});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.restaurant,
          title: context.lang.ingredientUsedInMealsTitle,
        ),
        const SizedBox(height: 8),
        if (usages.isEmpty)
          _EmptyState(
            icon: Icons.no_meals_outlined,
            label: context.lang.ingredientUsedInMealsEmpty,
          )
        else
          ...usages.map((meal) {
            return _ListSurface(
              leading: Icons.restaurant_outlined,
              title: meal.name,
              subtitle: meal.status,
              trailing: _formatDate(meal.plannedAt),
              onTap: () {
                context.router.push(routes.MealRoute(mealId: meal.mealId));
              },
            );
          }),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final IngredientHistoryEntryData entry;

  const _HistoryItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateTime(entry.createdAt),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  ConfidenceLevelX.fromDouble01(
                    entry.nutritionConfidence,
                  ).label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MacroChip(label: 'W', value: entry.carbsPer100g),
                _MacroChip(label: 'T', value: entry.fatPer100g),
                _MacroChip(label: 'B', value: entry.proteinPer100g),
                _MacroChip(
                  label: context.lang.ingredientFiberShortLabel,
                  value: entry.fiberPer100g,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSurface extends StatelessWidget {
  final IconData leading;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;
  final IconData? trailingIcon;
  final String? trailingTooltip;

  const _ListSurface({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.trailingIcon,
    this.trailingTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(leading, color: colors.primary),
        title: Text(title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: _ListSurfaceTrailing(
          label: trailing,
          hasAction: onTap != null,
          icon: trailingIcon,
          tooltip: trailingTooltip,
        ),
      ),
    );
  }
}

class _ListSurfaceTrailing extends StatelessWidget {
  final String label;
  final bool hasAction;
  final IconData? icon;
  final String? tooltip;

  const _ListSurfaceTrailing({
    required this.label,
    required this.hasAction,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: Theme.of(context).textTheme.labelLarge);
    if (!hasAction) {
      return text;
    }

    final actionIcon = Icon(
      icon ?? Icons.chevron_right,
      size: 20,
      color: Theme.of(context).colorScheme.outline,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        const SizedBox(width: 4),
        if (tooltip == null)
          actionIcon
        else
          Tooltip(message: tooltip!, child: actionIcon),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: colors.outline),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;

  const _MacroChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          '$label ${_formatNumber(value)} g',
          style: Theme.of(context).textTheme.labelMedium,
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

String _formatDate(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  return '$day.$month.${dateTime.year}';
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${_formatDate(dateTime)} $hour:$minute';
}
