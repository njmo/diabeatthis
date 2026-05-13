import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/widgets/delete_confirmation_dialog.dart';
import '../controllers/meal_details_controller.dart';
import '../models/meal_page_state.dart';
import '../widgets/meal_details/meal_activity_analysis_section.dart';
import '../widgets/meal_details/meal_advisor_result_section.dart';
import '../widgets/meal_details/meal_basic_info_section.dart';
import '../widgets/meal_details/meal_charts_section.dart';
import '../widgets/meal_details/meal_header.dart';
import '../widgets/meal_details/meal_nutrition_analysis_section.dart';
import '../widgets/meal_details/meal_snapshots_section.dart';
import '../widgets/meal_details/meal_transition_analysis_section.dart';

@RoutePage()
class MealPage extends ConsumerWidget {
  final int mealId;

  const MealPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealDetailsControllerProvider(mealId));

    return Scaffold(
      appBar: AppBar(
        title: state.maybeWhen(
          data: (value) => Text(value.details.meal.name),
          orElse: () => Text(''),
        ),
        actions: state.maybeWhen(
          data: (value) => [
            MealDeleteAction(mealId: mealId, mealName: value.details.meal.name),
          ],
          orElse: () => const [],
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Błąd: $error')),
        data: (value) => MealPageBody(state: value),
      ),
    );
  }
}

class MealDeleteAction extends ConsumerWidget {
  final int mealId;
  final String mealName;

  const MealDeleteAction({
    super.key,
    required this.mealId,
    required this.mealName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Usuń posiłek',
      icon: const Icon(Icons.delete_outline),
      onPressed: () => _confirmAndDeleteMeal(context, ref),
    );
  }

  Future<void> _confirmAndDeleteMeal(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Usunąć posiłek?',
      message:
          'Posiłek "$mealName" zostanie usunięty razem ze składnikami, podsumowaniem i wynikami analizy.',
      confirmLabel: 'Usuń posiłek',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final router = context.router;

    try {
      await ref
          .read(mealDetailsControllerProvider(mealId).notifier)
          .deleteMeal();
      if (!context.mounted) {
        return;
      }
      final didPop = await router.maybePop(mealId);
      if (!didPop) {
        await router.replace(const routes.DashboardRoute());
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Posiłek został usunięty')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Nie udało się usunąć posiłku: $error')),
      );
    }
  }
}

class MealPageBody extends ConsumerWidget {
  final MealPageState state;

  const MealPageBody({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = state.details;
    final bottomPadding = 16 + MediaQuery.viewPaddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      children: [
        MealHeader(state: state),
        const SizedBox(height: 12),
        MealBasicInfoSection(details: details),
        MealNutritionAnalysisSection(details: details),
        MealAdvisorResultSection(details: details),
        if (details.meal.isEaten)
          MealChartsSection(
            details: details,
            analysis: state.analysis,
            analysisError: state.analysisError,
            selectedTimestamp: state.selectedTimestamp,
          ),
        if (details.meal.isEaten && state.analysis != null)
          MealActivityAnalysisSection(
            mealId: details.meal.id,
            analysis: state.analysis!,
          ),
        MealTransitionAnalysisSection(details: details),
        MealSnapshotsSection(details: details),
      ],
    );
  }
}
