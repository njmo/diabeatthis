import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/form_section.dart';
import '../controllers/meal_summary_controller.dart';
import '../providers/meal_summary_item_ids_provider.dart';
import '../widgets/meal_summary_carbs_hint_card.dart';
import '../widgets/meal_summary_extra_items_section.dart';
import '../widgets/meal_summary_item_row.dart';

@RoutePage()
class MealSummaryPage extends ConsumerWidget {
  final int mealId;

  const MealSummaryPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDraft = ref.watch(mealSummaryControllerProvider(mealId));
    final itemIds = ref.watch(mealSummaryItemIdsProvider(mealId));
    final notifier = ref.read(mealSummaryControllerProvider(mealId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Ile zjadłeś?')),
      body: asyncDraft.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Nie udało się wczytać: $e')),
        data: (draft) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  'Sprawdź posiłek',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Wybierz ile porcji zostało zjedzone. Jeśli była dokładka, dodaj ją niżej.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                MealSummaryCarbsHintCard(draft: draft),
                const SizedBox(height: 24),
                FormSection(
                  icon: Icons.restaurant,
                  title: 'Składniki z planu',
                  subtitle: 'Dla każdego składnika ustaw zjedzoną ilość.',
                  children: [
                    for (final itemId in itemIds)
                      MealSummaryItemRow(
                        mealId: mealId,
                        mealIngredientId: itemId,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                MealSummaryExtraItemsSection(
                  mealId: mealId,
                  items: draft.extraItems,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: asyncDraft.maybeWhen(
        data: (_) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: () async {
              await notifier.saveSummary();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Zapisz podsumowanie'),
          ),
        ),
        orElse: () => null,
      ),
    );
  }
}
