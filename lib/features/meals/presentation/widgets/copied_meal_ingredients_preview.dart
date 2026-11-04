import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import '../../data/mappers/copy_recorded_meal_ingredient.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'copied_meal_preview_header.dart';
import 'copied_meal_preview_ingredient_list.dart';
import 'copied_meal_preview_load_error.dart';

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
        CopiedMealPreviewHeader(source: source, onBack: onBack),
        Flexible(
          child: ingredients.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                heightFactor: 1,
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => CopiedMealPreviewLoadError(
              error: error,
              stackTrace: stackTrace,
              mealId: source is CopiedMealFromMeal ? source.id : null,
              onRetry: () => ref.invalidate(provider),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    heightFactor: 1,
                    child: Text(context.lang.copiedMealNoIngredients),
                  )
                : CopiedMealPreviewIngredientList(
                    items: source is CopiedMealFromMeal
                        ? items.map(copyRecordedMealIngredient).toList()
                        : items,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed:
              ingredients.isLoading ||
                  ingredients.hasError ||
                  (ingredients.value?.isEmpty ?? true)
              ? null
              : onUse,
          icon: const Icon(Icons.content_copy_rounded),
          label: Text(context.lang.copiedMealUseIngredients),
        ),
      ],
    );
  }
}
