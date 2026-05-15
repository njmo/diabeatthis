import 'package:flutter/material.dart';

import '../../../../../common/widgets/search_text_field.dart';
import '../../../../../core/domain/model/ingredient.dart';
import '../../../../ingredients/presentation/widgets/selected_ingredient_chips.dart';

class MealListFilters extends StatelessWidget {
  final TextEditingController queryController;
  final List<Ingredient> selectedIngredients;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final VoidCallback onAddIngredient;
  final ValueChanged<int> onRemoveIngredient;
  final VoidCallback onClearIngredients;

  const MealListFilters({
    super.key,
    required this.queryController,
    required this.selectedIngredients,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onAddIngredient,
    required this.onRemoveIngredient,
    required this.onClearIngredients,
  });

  @override
  Widget build(BuildContext context) {
    const filterRowHeight = 48.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: filterRowHeight,
                  child: SearchTextField(
                    controller: queryController,
                    hintText: 'Szukaj posiłku po nazwie',
                    onChanged: onQueryChanged,
                    onClear: onClearQuery,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IngredientFilterButton(
                height: filterRowHeight,
                onPressed: onAddIngredient,
              ),
            ],
          ),
          if (selectedIngredients.isNotEmpty) ...[
            const SizedBox(height: 5),
            SelectedIngredientChips(
              ingredients: selectedIngredients,
              onRemove: onRemoveIngredient,
              onClearAll: onClearIngredients,
              variant: SelectedIngredientChipsVariant.mealList,
            ),
          ],
        ],
      ),
    );
  }
}

class IngredientFilterButton extends StatelessWidget {
  final double height;
  final VoidCallback onPressed;

  const IngredientFilterButton({
    super.key,
    required this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height,
      height: height,
      child: IconButton.outlined(
        tooltip: 'Dodaj filtr składników',
        icon: const Icon(Icons.add_chart_sharp),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
