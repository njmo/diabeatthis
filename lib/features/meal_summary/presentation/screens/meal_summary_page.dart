import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/form_section.dart';
import '../../domain/use_cases/finalize_meal_summary_use_case.dart';
import '../controllers/meal_summary_controller.dart';
import '../models/meal_summary_draft.dart';
import '../providers/meal_summary_item_ids_provider.dart';
import '../utils/meal_summary_carbs_delta.dart';
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
        data: (draft) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _saveSummary(
                    context: context,
                    notifier: notifier,
                    draft: draft,
                    mode: MealSummarySaveMode.continueEating,
                  ),
                  icon: const Icon(Icons.restaurant),
                  label: const Text('Zapisz dokładkę i wróć do jedzenia'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _saveSummary(
                    context: context,
                    notifier: notifier,
                    draft: draft,
                    mode: MealSummarySaveMode.finishMeal,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Zakończ posiłek'),
                ),
              ),
            ],
          ),
        ),
        orElse: () => null,
      ),
    );
  }

  Future<void> _saveSummary({
    required BuildContext context,
    required MealSummaryControllerNotifier notifier,
    required MealSummaryDraft draft,
    required MealSummarySaveMode mode,
  }) async {
    final delta = calculateMealSummaryCarbsDelta(draft);
    await notifier.saveSummary(mode: mode);

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_dialogTitle(delta)),
        content: Text(_dialogMessage(delta, mode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  String _dialogTitle(MealSummaryCarbsDelta delta) {
    if (delta.isPositive) {
      return '+${delta.roundedTotal}g węglowodanów';
    }
    if (delta.isNegative) {
      return '${delta.roundedTotal}g węglowodanów';
    }
    return 'Bez zmiany węglowodanów';
  }

  String _dialogMessage(MealSummaryCarbsDelta delta, MealSummarySaveMode mode) {
    final suffix = mode == MealSummarySaveMode.continueEating
        ? '\n\nPosiłek wrócił do statusu jedzenia. Kolejne podsumowanie zacznie od zapisanych wartości.'
        : '';

    if (delta.isPositive) {
      return 'Wpisz +${delta.roundedTotal}g w AAPS jako dodatkowe węglowodany. AAPS policzy insulinę według profilu.$suffix';
    }
    if (delta.isNegative) {
      return 'Zjedzono o ${delta.roundedTotal.abs()}g węglowodanów mniej niż plan. Jeśli bolus był na pełny plan, rozważ dojedzenie około ${delta.roundedTotal.abs()}g węglowodanów.$suffix';
    }
    return 'Zjedzone węglowodany są zgodne z planem.$suffix';
  }
}
