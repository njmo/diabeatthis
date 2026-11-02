import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/portions/standard_portion_names.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../utils/meal_ingredient_portion_formatters.dart';

class IngredientAmountPortions extends HookConsumerWidget {
  const IngredientAmountPortions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mealIngredientsDraftProvider);
    final id = draft.ingredient.getIngredientIdOrNull();
    final data = id == null
        ? null
        : ref.watch(portionsByIngredientByQueryProvider(id, ''));
    final selections = [
      for (final portion in data?.asData?.value ?? [])
        PortionSelection.existing(
          id: portion.id,
          name: portion.name,
          unitHint: portion.unitHint,
        ),
    ];
    final controller = ref.read(addMealIngredientStageProvider.notifier);
    for (final portion in controller.inlineDefinedPortions) {
      if (!selections.contains(portion)) selections.add(portion);
    }
    final selected = draft.ingredientPortion.portion;
    if (!draft.usesGramAmount && !selections.contains(selected)) {
      selections.add(selected);
    }
    final scroll = useScrollController();
    useEffect(() {
      final index = selections.indexOf(selected);
      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) {
            scroll.jumpTo(
              (index * 146.0).clamp(0.0, scroll.position.maxScrollExtent),
            );
          }
        });
      }
      return null;
    }, [selected, selections.length]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.addIngredientPickPortionTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        if (data?.isLoading == true) const LinearProgressIndicator(),
        SizedBox(
          height: 72 * MediaQuery.textScalerOf(context).scale(14) / 14,
          child: ListView.separated(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            itemCount: selections.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == selections.length) {
                return SizedBox(
                  width: 140,
                  child: OutlinedButton.icon(
                    onPressed: controller.defineInlinePortion,
                    icon: const Icon(Icons.add, size: 18),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    label: Text(context.lang.portionNewTitle),
                  ),
                );
              }
              return IngredientAmountPortionChoice(
                portion: selections[index],
                selected: selected == selections[index],
                onSelected: () =>
                    controller.selectInlinePortion(selections[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(context.lang.ingredientPortionsTitle),
            ),
            ButtonSegment(
              value: true,
              label: Text(context.lang.addIngredientAddInGrams),
            ),
          ],
          selected: {draft.usesGramAmount},
          onSelectionChanged: (values) {
            if (values.single) {
              controller.selectInlinePortion(const PortionSelection.empty());
            } else if (selections.isNotEmpty) {
              controller.selectInlinePortion(selections.first);
            } else {
              controller.defineInlinePortion();
            }
          },
        ),
      ],
    );
  }
}

class IngredientAmountPortionChoice extends ConsumerWidget {
  const IngredientAmountPortionChoice({
    super.key,
    required this.portion,
    required this.selected,
    required this.onSelected,
  });
  final PortionSelection portion;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mealIngredientsDraftProvider);
    final current = draft.ingredientPortion.portion == portion;
    final stored =
        draft.ingredient.getIngredientIdOrNull() != null &&
            (!current || draft.ingredientPortion.amount <= 0)
        ? ref.watch(gramsPerPortionProvider(draft.ingredient, portion))
        : null;
    final grams = current && draft.ingredientPortion.amount > 0
        ? draft.ingredientPortion.amount
        : ref
                  .read(addMealIngredientStageProvider.notifier)
                  .inlinePortionWeight(portion) ??
              stored?.asData?.value;
    final name = portion.map(
      draft: (p) => p.name,
      existing: (p) => p.name,
      empty: (_) => '',
    );
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 140,
      child: Material(
        color: selected
            ? colors.secondaryContainer
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        localizedPortionName(name, context.lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  grams == null
                      ? (stored?.isLoading == true
                            ? context.lang.commonLoading
                            : context.lang.amountMissingPortionWeight)
                      : '${grams.formattedAmount} g',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
