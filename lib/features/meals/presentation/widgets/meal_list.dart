import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/delete_confirmation_dialog.dart';
import '../../../../core/domain/model/meal.dart' as domain;
import '../../../ingredients/data/providers/ingredient_filter_controller.dart';
import '../../../ingredients/presentation/widgets/ingredient_list_filter.dart';
import '../../data/domain/use_cases/load_meal_page_by_filter_use_case.dart';
import '../controllers/meal_list_controller.dart';
import 'meal_list/meal_list_content.dart';

class MealList extends ConsumerWidget {
  const MealList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(mealListControllerProvider);
    final controller = ref.read(mealListControllerProvider.notifier);
    final mealsState = ref.watch(
      mealListWindowProvider(
        filter: listState.filter,
        limit: listState.visibleLimit,
      ),
    );
    ref.listen(ingredientFilterProvider, (_, _) {
      controller.setIngredientFilterItems(ref.read(ingredientFilterProvider));
    });

    Future<void> openMealDetails(domain.Meal meal) async {
      await context.router.push<int>(routes.MealRoute(mealId: meal.id));
    }

    return SafeArea(
      top: false,
      child: Column(
        children: [
          IngredientListFilter(
            hintText: context.lang.mealSearchHint,
            onQueryChanged: controller.setQuery,
          ),
          Expanded(
            child: MealListContent(
              meals: mealsState.value ?? const [],
              isInitialLoading:
                  mealsState.isLoading && (mealsState.value?.isEmpty ?? true),
              isLoadingMore:
                  mealsState.isLoading &&
                  (mealsState.value?.isNotEmpty ?? false),
              hasMore:
                  (mealsState.value?.length ?? 0) == listState.visibleLimit,
              hasError: mealsState.hasError,
              onLoadMore: controller.loadNextPage,
              onRetry: () {
                ref.invalidate(
                  mealListWindowProvider(
                    filter: listState.filter,
                    limit: listState.visibleLimit,
                  ),
                );
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
      title: context.lang.mealDeleteTitle,
      message: context.lang.mealDeleteMessage(meal.name),
      confirmLabel: context.lang.mealDeleteConfirm,
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
        SnackBar(content: Text(context.lang.mealDeleteSuccess)),
      );
      return true;
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.lang.mealDeleteFailed(error))),
        );
      }
      return false;
    }
  }
}
