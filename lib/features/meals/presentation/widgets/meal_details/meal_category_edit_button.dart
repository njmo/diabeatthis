import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_category.dart';
import '../../../../../common/widgets/meal_category_field.dart';
import '../../controllers/meal_category_controller.dart';

class MealCategoryEditButton extends ConsumerWidget {
  const MealCategoryEditButton({super.key, required this.mealId});
  final int mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealCategoryControllerProvider(mealId));
    return TextButton.icon(
      icon: const Icon(Icons.restaurant_outlined),
      label: Text(context.lang.mealEditCategory),
      onPressed: state.isLoading
          ? null
          : () async {
              try {
                final controller = ref.read(
                  mealCategoryControllerProvider(mealId).notifier,
                );
                final currentCategory = await controller.load();
                if (!context.mounted) return;
                final category = await showModalBottomSheet<MealCategory>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (sheetContext) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: MealCategoryField(
                        value: currentCategory,
                        onChanged: (value) {
                          if (value != null) Navigator.pop(sheetContext, value);
                        },
                      ),
                    ),
                  ),
                );
                if (category == null || !context.mounted) return;
                await controller.saveCategory(category, context.lang);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.lang.addMealSaveError(error)),
                    ),
                  );
                }
              }
            },
    );
  }
}
