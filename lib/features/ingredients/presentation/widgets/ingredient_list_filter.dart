import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/search_text_field.dart';
import '../../data/models/ingredient_filter_limits.dart';
import '../../data/providers/ingredient_filter_controller.dart';
import 'ingredient_multi_picker_sheet.dart';
import 'selected_ingredient_chips.dart';

class IngredientListFilter extends HookConsumerWidget {
  final String hintText;
  final ValueChanged<String> onQueryChanged;
  final EdgeInsetsGeometry padding;

  const IngredientListFilter({
    super.key,
    required this.hintText,
    required this.onQueryChanged,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 6),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filterRowHeight = 48.0;
    final queryController = useTextEditingController();
    final selectedIngredients = ref.watch(ingredientFilterProvider);
    final controller = ref.read(ingredientFilterProvider.notifier);
    final hasRemovableIngredients = selectedIngredients.any(
      (ingredient) => ingredient.removable,
    );
    final canAddIngredient =
        selectedIngredients.length < ingredientFilterSelectionLimit;

    Future<void> addIngredientFilter() async {
      ref
          .read(ingredientFilterDraftProvider.notifier)
          .overrideItems(ref.read(ingredientFilterProvider));

      final selected = await showIngredientMultiPickerSheet(context: context);
      if (selected == null) {
        return;
      }
      controller.overrideItems(selected);
    }

    return Padding(
      padding: padding,
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
                    hintText: hintText,
                    onChanged: onQueryChanged,
                  ),
                ),
              ),
              if (canAddIngredient) ...[
                const SizedBox(width: 8),
                IngredientFilterButton(
                  height: filterRowHeight,
                  onPressed: addIngredientFilter,
                ),
              ],
            ],
          ),
          if (selectedIngredients.isNotEmpty) ...[
            const SizedBox(height: 5),
            SelectedIngredientChips(
              ingredients: selectedIngredients,
              onRemove: controller.removeIngredient,
              onClearAll: hasRemovableIngredients
                  ? controller.clearAdditionalIngredients
                  : null,
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
