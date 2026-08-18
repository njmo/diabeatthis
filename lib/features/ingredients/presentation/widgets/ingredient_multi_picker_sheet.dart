import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/models/ingredient_filter_item.dart';
import '../../data/models/ingredient_filter_limits.dart';
import '../../data/providers/ingredient_filter_controller.dart';
import '../../data/providers/ingredient_provider.dart';
import 'ingredient_multi_picker_footer.dart';
import 'ingredient_multi_picker_result_list.dart';
import 'ingredient_multi_picker_search_field.dart';
import 'selected_ingredient_chips.dart';

Future<List<IngredientFilterItem>?> showIngredientMultiPickerSheet({
  required BuildContext context,
}) {
  return showModalBottomSheet<List<IngredientFilterItem>>(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const IngredientMultiPickerSheet(),
  );
}

class IngredientMultiPickerSheet extends HookConsumerWidget {
  const IngredientMultiPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = useTextEditingController();
    final query = useState('');
    final pickedIngredients = ref.watch(ingredientFilterDraftProvider);
    final controller = ref.read(ingredientFilterDraftProvider.notifier);
    final normalizedQuery = query.value.trim();
    final ingredients = normalizedQuery.isEmpty
        ? ref.watch(latestIngredientsProvider)
        : ref.watch(ingredientsByQueryProvider(normalizedQuery));
    final pickedIngredientIds = pickedIngredients
        .map((ingredient) => ingredient.id)
        .toSet();

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
                onClear: () {
                  queryController.clear();
                  query.value = '';
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pickedIngredients.isNotEmpty) ...[
                      SelectedIngredientsPanel(
                        ingredients: pickedIngredients,
                        onRemove: controller.removeIngredient,
                        onClearAll:
                            pickedIngredients.any(
                              (ingredient) => ingredient.removable,
                            )
                            ? controller.clearAdditionalIngredients
                            : null,
                      ),
                      const Divider(height: 1),
                    ],
                    Expanded(
                      child: IngredientMultiPickerResultList(
                        ingredients: ingredients,
                        selectedIngredientIds: pickedIngredientIds,
                        onToggleIngredient: (ingredient) {
                          final pickedIngredient = pickedIngredients
                              .where((item) => item.id == ingredient.id)
                              .firstOrNull;
                          if (pickedIngredient != null) {
                            if (pickedIngredient.removable) {
                              controller.removeIngredient(ingredient.id);
                            }
                            return;
                          }

                          if (pickedIngredients.length >=
                              ingredientFilterSelectionLimit) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.lang.ingredientSelectionLimit,
                                ),
                              ),
                            );
                            return;
                          }

                          controller.addIngredient(
                            ingredient.toFilterItem(removable: true),
                          );
                          queryController.clear();
                          query.value = '';
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    IngredientMultiPickerFooter(
                      onConfirm: () =>
                          Navigator.of(context).pop(pickedIngredients),
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

class SelectedIngredientsPanel extends StatelessWidget {
  final List<IngredientFilterItem> ingredients;
  final ValueChanged<int> onRemove;
  final VoidCallback? onClearAll;

  const SelectedIngredientsPanel({
    super.key,
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
        ),
      ),
    );
  }
}
