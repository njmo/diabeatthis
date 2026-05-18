import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/model/ingredient.dart';
import '../../data/models/ingredient_filter_limits.dart';
import '../../data/providers/ingredient_provider.dart';
import 'ingredient_multi_picker_footer.dart';
import 'ingredient_multi_picker_result_list.dart';
import 'ingredient_multi_picker_search_field.dart';
import 'selected_ingredient_chips.dart';

Future<List<Ingredient>?> showIngredientMultiPickerSheet({
  required BuildContext context,
  required List<Ingredient> initialSelection,
}) {
  return showModalBottomSheet<List<Ingredient>>(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) =>
        IngredientMultiPickerSheet(initialSelection: initialSelection),
  );
}

class IngredientMultiPickerSheet extends HookConsumerWidget {
  final List<Ingredient> initialSelection;

  const IngredientMultiPickerSheet({super.key, required this.initialSelection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = useTextEditingController();
    final query = useState('');
    final pickedIngredients = useState<List<Ingredient>>(initialSelection);
    final normalizedQuery = query.value.trim();
    final ingredients = normalizedQuery.isEmpty
        ? ref.watch(latestIngredientsProvider)
        : ref.watch(ingredientsByQueryProvider(normalizedQuery));
    final pickedIngredientIds = pickedIngredients.value
        .map((ingredient) => ingredient.id)
        .toSet();

    void clearQuery() {
      queryController.clear();
      query.value = '';
    }

    void toggleIngredient(Ingredient ingredient) {
      final ingredientId = ingredient.id;
      final isSelected = pickedIngredientIds.contains(ingredientId);
      if (isSelected) {
        pickedIngredients.value = [
          for (final item in pickedIngredients.value)
            if (item.id != ingredientId) item,
        ];
        return;
      }

      if (pickedIngredients.value.length >= ingredientFilterSelectionLimit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Możesz wybrać maksymalnie 4 składniki'),
          ),
        );
        return;
      }
      pickedIngredients.value = [...pickedIngredients.value, ingredient];
      clearQuery();
    }

    void removeIngredient(int ingredientId) {
      pickedIngredients.value = [
        for (final ingredient in pickedIngredients.value)
          if (ingredient.id != ingredientId) ingredient,
      ];
    }

    final mediaQuery = MediaQuery.of(context);
    final sheetHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.bottom) * 0.85;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight.clamp(360.0, mediaQuery.size.height * 0.85),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IngredientMultiPickerSearchField(
                controller: queryController,
                query: query.value,
                onChanged: (value) => query.value = value,
                onClear: clearQuery,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pickedIngredients.value.isNotEmpty) ...[
                      _SelectedIngredientsPanel(
                        ingredients: pickedIngredients.value,
                        onRemove: removeIngredient,
                        onClearAll: () => pickedIngredients.value = const [],
                      ),
                      const Divider(height: 1),
                    ],
                    Expanded(
                      child: IngredientMultiPickerResultList(
                        ingredients: ingredients,
                        selectedIngredientIds: pickedIngredientIds,
                        onToggleIngredient: toggleIngredient,
                      ),
                    ),
                    const Divider(height: 1),
                    IngredientMultiPickerFooter(
                      onConfirm: () =>
                          Navigator.of(context).pop(pickedIngredients.value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedIngredientsPanel extends StatelessWidget {
  final List<Ingredient> ingredients;
  final ValueChanged<int> onRemove;
  final VoidCallback onClearAll;

  const _SelectedIngredientsPanel({
    required this.ingredients,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 72),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: SelectedIngredientChips(
          ingredients: ingredients,
          onRemove: onRemove,
          onClearAll: onClearAll,
          variant: SelectedIngredientChipsVariant.sheet,
        ),
      ),
    );
  }
}
