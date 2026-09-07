import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'copied_meal_history_button.dart';
import 'copied_meal_ingredient_row.dart';

class CopiedMealIngredientsPreview extends ConsumerWidget {
  const CopiedMealIngredientsPreview({
    super.key,
    required this.source,
    required this.onUse,
    required this.onBack,
  });

  final CopiedMealType source;
  final VoidCallback onUse;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = source is CopiedMealFromTemplate
        ? getMealIngredientsDraftForMealTemplateProvider(source.id)
        : getMealIngredientsDraftForMealProvider(source.id);
    final ingredients = ref.watch(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BottomSheetStepHeader(title: source.name, onBack: onBack),
        Padding(
          padding: const EdgeInsets.only(left: 48, bottom: 16),
          child: Text(
            MaterialLocalizations.of(context).formatMediumDate(source.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ingredients.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(provider),
                child: Text(context.lang.copiedMealLoadRetry),
              ),
            ),
            data: (items) => items.isEmpty
                ? Center(child: Text(context.lang.copiedMealNoIngredients))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) =>
                        CopiedMealIngredientRow(item: items[index]),
                  ),
          ),
        ),
        if (source is CopiedMealFromMeal)
          Align(
            alignment: Alignment.centerLeft,
            child: CopiedMealHistoryButton(source: source),
          ),
        const SizedBox(height: 12),
        Text(
          context.lang.copiedMealUseHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed:
              ingredients.isLoading ||
                  ingredients.hasError ||
                  (ingredients.value?.isEmpty ?? true)
              ? null
              : onUse,
          icon: const Icon(Icons.content_copy),
          label: Text(context.lang.copiedMealUseIngredients),
        ),
      ],
    );
  }
}
