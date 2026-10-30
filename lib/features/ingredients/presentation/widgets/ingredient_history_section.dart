import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../data/models/ingredient_details_data.dart';
import '../../data/models/ingredient_history_entry_data.dart';
import '../../data/models/ingredient_nutrition_values.dart';
import 'ingredient_history_change_card.dart';
import 'ingredient_section_empty.dart';

class IngredientHistorySection extends StatelessWidget {
  const IngredientHistorySection({
    super.key,
    required this.history,
    required this.ingredient,
  });

  final List<IngredientHistoryEntryData> history;
  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final entries = [...history]
      ..sort((a, b) {
        final time = b.createdAt.compareTo(a.createdAt);
        return time != 0 ? time : b.id.compareTo(a.id);
      });
    var after = IngredientNutritionValues.current(ingredient);
    final cards = <Widget>[];
    for (final entry in entries) {
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
      cards.add(
        IngredientHistoryChangeCard(
          entry: entry,
          after: after,
          isReference: ingredient.isReference,
        ),
      );
      after = IngredientNutritionValues.history(entry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.ingredientChangeHistoryTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          IngredientSectionEmpty(
            icon: Icons.history_toggle_off,
            label: context.lang.ingredientMacroHistoryEmpty,
          )
        else
          ...cards,
      ],
    );
  }
}
