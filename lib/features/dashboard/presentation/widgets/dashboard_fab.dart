import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../data/providers/meal_add_provider.dart';
import 'meal_status_dialog.dart';

class DashboardFAB extends HookConsumerWidget {
  const DashboardFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var open = useState(false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open.value) ...[
          _buildOption(Icons.note_alt, 'Add note', () {
            open.value = false;
          }),
          const SizedBox(height: 8),
          _buildOption(Icons.sports_gymnastics, 'Add activity', () {
            context.router.push(routes.TestRoute());
            open.value = false;
          }),
          const SizedBox(height: 8),
          _buildOption(Icons.bakery_dining_rounded, 'Eat simple', () async {
            final mealIngredient = await showModalBottomSheet<MealIngredientsDraft>(
              context: context,
              useRootNavigator: false,
              isScrollControlled: true,
              builder: (_) => AddMealIngredient(),
            );
            if (mealIngredient != null) {
              final draft = ref.watch(mealDraftProvider.notifier);
              draft.addMealIngredient(mealIngredient);
              draft.setName("QM: ${mealIngredient.ingredient.name}");
              final addedMeal = ref.watch(mealAddProvider.notifier).addMeal(ref.read(mealDraftProvider));
              addedMeal.then((meal) async{
                final action = await showDialog<String?>(
                  barrierDismissible: true,
                  context: context,
                  builder: (context) => MealStatusDialog(meal: meal),
                );
                if (action != null) {
                  ref.read(updateMealProvider(meal, action));
                }
              });
            }
            open.value = false;
          }),
          const SizedBox(height: 8),
          _buildOption(Icons.restaurant, 'Plan meal', () {
            context.router.push(routes.AddMealRoute());
            open.value = false;
          }),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: () => open.value = !open.value,
          child: Icon(open.value ? Icons.close : Icons.add),
        ),
      ],
    );
  }

  Widget _buildOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
