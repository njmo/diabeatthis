import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../common/widgets/show_meal_category_menu.dart';
import '../../controllers/meal_category_controller.dart';

class MealCategoryEditButton extends StatelessWidget {
  const MealCategoryEditButton({
    super.key,
    required this.mealId,
    this.assign = false,
  });
  final bool assign;
  final int mealId;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.restaurant_outlined),
      label: Text(
        assign
            ? context.lang.mealAssignCategory
            : context.lang.mealEditCategory,
      ),
      onPressed: () async {
        final ref = ProviderScope.containerOf(context, listen: false);
        if (ref.read(mealCategoryControllerProvider(mealId)).isLoading) return;
        final subscription = ref.listen(
          mealCategoryControllerProvider(mealId),
          (_, _) {},
        );
        try {
          final controller = ref.read(
            mealCategoryControllerProvider(mealId).notifier,
          );
          final currentCategory = await controller.load();
          if (!context.mounted) return;
          final category = await showMealCategoryMenu(
            context,
            selected: currentCategory,
          );
          if (category == null || !context.mounted) return;
          await controller.saveCategory(category, context.lang);
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.lang.addMealSaveError(error))),
            );
          }
        } finally {
          subscription.close();
        }
      },
    );
  }
}
