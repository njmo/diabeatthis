import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'copied_meal_history_button.dart';
import 'copied_meal_preview_header.dart';
import 'copied_meal_preview_ingredient_list.dart';

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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CopiedMealPreviewHeader(
          source: source,
          onBack: onBack,
          onUse:
              ingredients.isLoading ||
                  ingredients.hasError ||
                  (ingredients.value?.isEmpty ?? true)
              ? null
              : onUse,
        ),
        Flexible(
          child: ingredients.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                heightFactor: 1,
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => Center(
              heightFactor: 1,
              child: TextButton(
                onPressed: () => ref.invalidate(provider),
                child: Text(context.lang.copiedMealLoadRetry),
              ),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    heightFactor: 1,
                    child: Text(context.lang.copiedMealNoIngredients),
                  )
                : CopiedMealPreviewIngredientList(items: items),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.lang.copiedMealUseHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (source is CopiedMealFromMeal) ...[
          const SizedBox(height: 16),
          CopiedMealHistoryButton(source: source),
        ],
      ],
    );
  }
}
