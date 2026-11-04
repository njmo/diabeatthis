import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/sheet_choice_tile.dart';
import '../../../data/model/copied_meal_type.dart';
import '../../../data/providers/meal_ingredients_list_provider.dart';
import '../add_ingredient_to_meal_draft.dart';
import '../copied_meal_source_card.dart';
import '../meal_ingredients_list.dart';

class MealCompositionStep extends ConsumerWidget {
  const MealCompositionStep({
    super.key,
    required this.picker,
    required this.onPicked,
    required this.isCopying,
    this.source,
    this.retrospective = false,
  });
  final Future<CopiedMealType?> Function(BuildContext) picker;
  final Future<bool> Function(CopiedMealType) onPicked;
  final bool isCopying;
  final CopiedMealType? source;
  final bool retrospective;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(mealDraftIngredientsProvider);
    final hasIngredients = ingredients.isNotEmpty;
    Future<void> copy() async {
      final selected = await picker(context);
      if (selected == null || !context.mounted) return;
      if (hasIngredients) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.lang.mealCopyReplaceTitle),
            content: Text(context.lang.mealCopyReplaceMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.lang.mealCopyReplaceAction),
              ),
            ],
          ),
        );
        if (replace != true || !context.mounted) return;
      }
      await onPicked(selected);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (retrospective) ...[
          const SizedBox(height: 8),
          Text(context.lang.mealRetrospectiveFullPortionNote),
        ],
        const SizedBox(height: 16),
        if (isCopying) ...[
          LinearProgressIndicator(semanticsLabel: context.lang.commonLoading),
          const SizedBox(height: 12),
        ],
        if (source != null) ...[
          CopiedMealSourceCard(
            source: source!,
            onChange: isCopying ? null : copy,
          ),
          const SizedBox(height: 16),
        ],
        if (hasIngredients) ...[
          Text(
            context.lang.mealIngredientsListCountTitle(ingredients.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const MealIngredientsList(compact: true),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isCopying
                ? null
                : () => addIngredientToMealDraft(context, ref),
            icon: const Icon(Icons.add),
            label: Text(context.lang.mealCompositionAddIngredient),
          ),
          if (source == null)
            TextButton.icon(
              onPressed: isCopying ? null : copy,
              icon: const Icon(Icons.content_copy_rounded),
              label: Text(context.lang.mealCompositionCopy),
            ),
        ] else ...[
          SheetChoiceTile(
            icon: Icons.add,
            title: context.lang.mealCompositionAddIngredient,
            onTap: isCopying
                ? null
                : () => addIngredientToMealDraft(context, ref),
          ),
          const SizedBox(height: 12),
          SheetChoiceTile(
            icon: Icons.history_rounded,
            title: context.lang.mealCompositionUsePrevious,
            onTap: isCopying ? null : copy,
          ),
        ],
      ],
    );
  }
}
