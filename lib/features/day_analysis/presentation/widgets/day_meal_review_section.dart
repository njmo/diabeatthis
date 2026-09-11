import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../meals/common/models/meal_wizard_relation_type.dart';
import '../../../meals/data/models/meal_review_timing.dart';
import '../../../meals/presentation/widgets/meal_review_timing_dialog.dart';
import '../../data/providers/day_context_provider.dart';
import '../../data/providers/day_meal_review_provider.dart';
import '../controllers/day_meal_review_controller.dart';
import 'day_meal_link_picker.dart';
import 'day_meal_review_tile.dart';

class DayMealReviewSection extends ConsumerWidget {
  final DateTime date;
  const DayMealReviewSection({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = dayMealReviewProvider(date);
    final entries = ref.watch(provider);
    final busy = ref.watch(dayMealReviewControllerProvider(date)).isLoading;
    Future<void> refresh() async {
      ref.invalidate(dayContextProvider);
      ref.invalidate(dayContextForDateProvider(date));
      ref.invalidate(provider);
      ref.invalidate(dayMealCandidatesProvider(date));
      try {
        await ref.read(provider.future);
      } catch (_) {
        // The page renders the loading error.
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Posiłki i wpisy kalkulatora',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        entries.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nie udało się pobrać listy. Nie wiadomo, ile wpisów wymaga sprawdzenia.',
              ),
              TextButton(
                onPressed: refresh,
                child: const Text('Spróbuj ponownie'),
              ),
            ],
          ),
          data: (items) {
            final pending = items.where((entry) => entry.meal == null).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pending > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '$pending do sprawdzenia',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                if (items.isEmpty)
                  const Text(
                    'Brak posiłków i wpisów kalkulatora w historii tego dnia.',
                  ),
                ...items.map(
                  (entry) => DayMealReviewTile(
                    key: ValueKey(entry.meal?.id ?? entry.wizards.first),
                    entry: entry,
                    busy: busy,
                    onLink: (wizard) => _pickMeal(context, ref, wizard),
                    onCreate: (wizard) => _createMeal(context, ref, wizard),
                    onUnlink: (id) => _unlink(context, ref, id),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickMeal(
    BuildContext context,
    WidgetRef ref,
    BolusWizard wizard,
  ) async {
    final choice =
        await showModalBottomSheet<
          ({int mealId, MealWizardRelationType type, bool requiresCompletion})
        >(
          context: context,
          isScrollControlled: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          builder: (_) => DayMealLinkPicker(date: date),
        );
    if (choice == null || !context.mounted) return;
    MealReviewTiming? timing;
    if (choice.requiresCompletion) {
      timing = await showDialog<MealReviewTiming>(
        context: context,
        builder: (_) => MealReviewTimingDialog(initialTime: wizard.createdAt),
      );
      if (timing == null || !context.mounted) return;
    }

    try {
      await ref
          .read(dayMealReviewControllerProvider(date).notifier)
          .link(wizard, choice.mealId, choice.type, timing: timing);
    } catch (_) {
      if (context.mounted) {
        _error(
          context,
          'Nie udało się zapisać powiązania. Odśwież listę i spróbuj ponownie.',
        );
      }
    }
  }

  Future<void> _createMeal(
    BuildContext context,
    WidgetRef ref,
    BolusWizard wizard,
  ) async {
    final meal = await context.router.push<Meal>(
      AddMealRoute(retrospective: true, initialEatenAt: wizard.createdAt),
    );
    if (meal == null || !context.mounted) return;
    final controller = ref.read(dayMealReviewControllerProvider(date).notifier);
    try {
      await controller.link(
        wizard,
        meal.id,
        MealWizardRelationType.initial,
        mealWasCreated: true,
      );
    } catch (_) {
      if (context.mounted) {
        _error(
          context,
          'Posiłek został zapisany, ale nie udało się go połączyć. Wybierz „Połącz z posiłkiem”; nie dodawaj go ponownie.',
        );
      }
    }
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(dayMealReviewControllerProvider(date).notifier).unlink(id);
    } catch (_) {
      if (context.mounted) {
        _error(context, 'Nie udało się usunąć powiązania. Spróbuj ponownie.');
      }
    }
  }

  void _error(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
