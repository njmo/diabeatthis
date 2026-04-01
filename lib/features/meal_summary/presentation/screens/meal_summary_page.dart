import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../controllers/meal_summary_controller.dart';
import '../providers/meal_summary_extra_items_provider.dart';
import '../providers/meal_summary_item_ids_provider.dart';
import '../widgets/meal_summary_item_row.dart';

@RoutePage()
class MealSummaryPage extends ConsumerWidget {
  final int mealId;

  const MealSummaryPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDraft = ref.watch(mealSummaryControllerProvider(mealId));
    final itemIds = ref.watch(mealSummaryItemIdsProvider(mealId));
    final extraItems = ref.watch(mealSummaryExtraItemsProvider(mealId));
    final notifier = ref.read(mealSummaryControllerProvider(mealId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Podsumowanie posiłku')),
      body: asyncDraft.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('error: $e')),
        data: (_) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: itemIds.length,
                  itemBuilder: (context, index) {
                    return MealSummaryItemRow(
                      mealId: mealId,
                      mealIngredientId: itemIds[index],
                    );
                  },
                ),
                const Divider(),
                Row(
                  children: [
                    const Text('Extra items'),
                    IconButton(
                      onPressed: () async {
                        final mealIngredient =
                            await showModalBottomSheet<MealIngredientsDraft>(
                              context: context,
                              useRootNavigator: false,
                              isScrollControlled: true,
                              builder: (_) => const AddMealIngredient(),
                            );

                        if (mealIngredient != null) {
                          notifier.addExtraItem(mealIngredient);
                        }
                      },
                      icon: const Icon(Icons.add_box, size: 20),
                    ),
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: extraItems.length,
                  itemBuilder: (context, index) {
                    final item = extraItems[index];
                    return ListTile(
                      title: Text(item.ingredient.name),
                      trailing: IconButton(
                        onPressed: () {
                          notifier.removeExtraItem(item);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    );
                  },
                ),
                const Divider(),
                FilledButton(
                  onPressed: () async {
                    notifier.saveSummary();
                    Navigator.pop(context);
                  },
                  child: const Text("Podsumuj"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
