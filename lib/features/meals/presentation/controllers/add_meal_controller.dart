import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import '../../data/domain/use_cases/add_meal_use_case.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';

part 'add_meal_controller.g.dart';

@riverpod
class AddMealControllerNotifier extends _$AddMealControllerNotifier {
  @override
  Future<Meal?> build() async {
    return null;
  }

  Future<void> copyFromSource(CopiedMealType source) async {
    final keepAliveLink = ref.keepAlive();
    try {
      final ingredients = await switch (source) {
        CopiedMealFromTemplate() => ref.read(
          getMealIngredientsDraftForMealTemplateProvider(source.id).future,
        ),
        CopiedMealFromMeal() => ref.read(
          getMealIngredientsDraftForMealProvider(source.id).future,
        ),
      };
      ref.read(mealDraftProvider.notifier).applySource(source, ingredients);
    } finally {
      keepAliveLink.close();
    }
  }

  Future<Meal> addMeal(MealDraft draft) async {
    final keepAliveLink = ref.keepAlive();
    state = const AsyncLoading();

    try {
      final useCase = ref.read(addMealUseCaseProvider);
      final meal = await useCase.call(draft);
      state = AsyncData(meal);
      return meal;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }
}
