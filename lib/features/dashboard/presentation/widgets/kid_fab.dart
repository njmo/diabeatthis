import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/model/activity.dart';
import '../../../../core/domain/model/activity_log.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../activity/presentation/widgets/activity_picker_dialog.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../data/providers/meal_add_provider.dart';
import 'meal_status_dialog.dart';

class KidFAB extends HookConsumerWidget {
  const KidFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var open = useState(false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open.value) ...[
          _buildOption(Icons.sports_gymnastics, 'Zacznij aktywność', () async {
            final activity = await showDialog<Activity?>(
              barrierDismissible: true,
              context: context,
              builder: (context) => ActivityPickerDialog(),
            );
            if (activity != null) {
              activity.when(
                existing: (id, name) {
                  print('Starting existing id: $id, name: $name');
                  ref.read(
                    insertActivityLogProvider(
                      ActivityLog.draft(
                        activityId: id,
                        startedAt: DateTime.now(),
                      ),
                    ),
                  );
                  ref.invalidate(getPendingActivityProvider);
                },
                draft: (name) async {
                  print('Adding draft: $name');
                  final act = await ref.read(
                    insertActivityProvider(Activity.draft(name: name)).future,
                  );
                  final id = act?.whenOrNull(existing: (id, name) => id);
                  print('Draft added with id: $id and name: ${act?.name}');
                  if (id != null) {
                    ref.read(
                      insertActivityLogProvider(
                        ActivityLog.draft(
                          activityId: id,
                          startedAt: DateTime.now(),
                        ),
                      )
                    );
                    print('Activity log added');
                    ref.invalidate(getPendingActivityProvider);
                  }
                },
              );
            }
            open.value = false;
          }),
          const SizedBox(height: 8),
          _buildOption(
            Icons.bakery_dining_rounded,
            'Zjedz coś na szybko',
            () async {
              final mealIngredient =
                  await showModalBottomSheet<MealIngredientsDraft>(
                    context: context,
                    useRootNavigator: false,
                    isScrollControlled: true,
                    builder: (_) => AddMealIngredient(),
                  );
              if (mealIngredient != null) {
                final draft = ref.watch(mealDraftProvider.notifier);
                draft.addMealIngredient(mealIngredient);
                draft.setName("QM: ${mealIngredient.ingredient.name}");
                final addedMeal = await ref
                    .watch(mealAddProvider.notifier)
                    .addMeal(ref.read(mealDraftProvider));

                  final action = await showDialog<String?>(
                    barrierDismissible: true,
                    context: context,
                    builder: (context) => MealStatusDialog(meal: addedMeal),
                  );
                  if (action != null) {
                    ref.read(updateMealProvider(addedMeal, action));
                  }
              }
              open.value = false;
            },
          ),
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
        width: 195,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
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
