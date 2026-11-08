import 'package:flutter/material.dart';

import '../../features/ingredients/data/models/ingredient_portion_data.dart';
import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/presentation/utils/meal_ingredient_portion_formatters.dart';
import '../../features/meals/presentation/widgets/ingredient_amount_portions.dart';
import '../../features/portions/data/drafts/portion_draft.dart';
import '../l10n/language.dart';

/// Offers recorded family portions without reading the device's local database.
class MealIngredientPortionChoices extends StatelessWidget {
  const MealIngredientPortionChoices({
    super.key,
    required this.draft,
    required this.portions,
    required this.onSelected,
  });
  final MealIngredientsDraft draft;
  final List<IngredientPortionData> portions;
  final ValueChanged<IngredientPortionData?> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = draft.ingredientPortion.portion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.addIngredientPickPortionTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 72 * MediaQuery.textScalerOf(context).scale(14) / 14,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: portions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final item = portions[index];
              final portion = PortionSelection.existing(
                id: item.portionId,
                name: item.name,
                unitHint: item.unitHint,
              );
              final isSelected = selected.maybeMap(
                existing: (value) => value.id == item.portionId,
                orElse: () => false,
              );
              return IngredientAmountPortionTile(
                portion: portion,
                selected: isSelected,
                grams: isSelected && draft.recordedGramsPerAmount != null
                    ? draft.recordedGramsPerAmount
                    : item.gramsPerPortion,
                onSelected: () => onSelected(item),
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
          onSelectionChanged: (values) =>
              onSelected(values.single ? null : portions.first),
        ),
      ],
    );
  }
}
