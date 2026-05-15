import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/widgets/delete_confirmation_dialog.dart';
import '../../../../core/domain/model/meal.dart' as domain;
import '../../../ingredients/presentation/widgets/ingredient_multi_picker_sheet.dart';
import '../controllers/meal_list_controller.dart';
import '../models/meal_list_state.dart';
import 'meal_list/meal_list_content.dart';
import 'meal_list/meal_list_filters.dart';

class MealList extends HookConsumerWidget {
  const MealList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = useTextEditingController();
    final asyncState = ref.watch(mealListControllerProvider);
    final controller = ref.read(mealListControllerProvider.notifier);
    final listState = asyncState.value ?? const MealListState.initial();

    useEffect(() {
      final query = listState.query;
      if (queryController.text != query) {
        queryController.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
      }
      return null;
    }, [listState.query]);

    Future<void> addIngredientFilter() async {
      final selected = await showIngredientMultiPickerSheet(
        context: context,
        initialSelection: listState.selectedIngredients,
      );
      if (selected == null) {
        return;
      }
      await controller.setIngredients(selected);
    }

    Future<void> openMealDetails(domain.Meal meal) async {
      final deletedMealId = await context.router.push<int>(
        routes.MealRoute(mealId: meal.id),
      );
      if (!context.mounted || deletedMealId == null) {
        return;
      }
      controller.removeMealFromList(deletedMealId);
    }

    return SafeArea(
      top: false,
      child: Column(
        children: [
          MealListFilters(
            queryController: queryController,
            selectedIngredients: listState.selectedIngredients,
            onQueryChanged: controller.setQuery,
            onClearQuery: () {
              queryController.clear();
              controller.setQuery('');
            },
            onAddIngredient: addIngredientFilter,
            onRemoveIngredient: controller.removeIngredient,
            onClearIngredients: controller.clearIngredients,
          ),
          Expanded(
            child: MealListContent(
              meals: listState.meals,
              isInitialLoading:
                  (asyncState.isLoading && asyncState.value == null) ||
                  (listState.meals.isEmpty && listState.isRefreshing),
              isLoadingMore: listState.isLoadingMore,
              hasMore: listState.hasMore,
              hasError: asyncState.hasError || listState.loadMoreError != null,
              onLoadMore: controller.loadNextPage,
              onRetry: () {
                if (asyncState.hasError) {
                  ref.invalidate(mealListControllerProvider);
                  return;
                }
                if (listState.meals.isEmpty) {
                  controller.retryCurrentFilter();
                  return;
                }
                controller.loadNextPage();
              },
              onMealTap: openMealDetails,
              onMealDelete: (meal) => _confirmAndDeleteMeal(
                context: context,
                controller: controller,
                meal: meal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmAndDeleteMeal({
    required BuildContext context,
    required MealListController controller,
    required domain.Meal meal,
  }) async {
    final confirmed = await showDeleteConfirmationDialog(
      context,
      title: 'Usunąć posiłek?',
      message:
          'Posiłek "${meal.name}" zostanie usunięty razem ze składnikami, podsumowaniem i wynikami analizy.',
      confirmLabel: 'Usuń posiłek',
    );
    if (!confirmed || !context.mounted) {
      return false;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.deleteMeal(meal.id);
      if (!context.mounted) {
        return true;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Posiłek został usunięty')),
      );
      return true;
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Nie udało się usunąć posiłku: $error')),
        );
      }
      return false;
    }
  }
}
