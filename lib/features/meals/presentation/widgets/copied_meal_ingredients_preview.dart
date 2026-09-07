import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import '../utils/meal_ingredient_portion_formatters.dart';

class CopiedMealIngredientsPreview extends ConsumerWidget {
  const CopiedMealIngredientsPreview({
    super.key,
    required this.source,
    required this.onUse,
  });

  final CopiedMealType source;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = source is CopiedMealFromTemplate
        ? getMealIngredientsDraftForMealTemplateProvider(source.id)
        : getMealIngredientsDraftForMealProvider(source.id);
    final ingredients = ref.watch(provider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ingredients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => TextButton(
          onPressed: () => ref.invalidate(provider),
          child: Text(context.lang.copiedMealLoadRetry),
        ),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty) Text(context.lang.copiedMealNoIngredients),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.ingredient.name),
                subtitle: Text(
                  '${item.amount.formattedAmount} ${unitLabelForAmount(item.amount, item.portionCountUnitLabel)} · ${item.portionDescription(portionAmount: item.ingredientPortion.amount, isLoading: false)}',
                ),
              ),
            const SizedBox(height: 8),
            Text(
              context.lang.copiedMealUseHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: items.isEmpty ? null : onUse,
              icon: const Icon(Icons.content_copy),
              label: Text(context.lang.copiedMealUseIngredients),
            ),
          ],
        ),
      ),
    );
  }
}
