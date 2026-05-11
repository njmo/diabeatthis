import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../data/domain/use_cases/add_meal_use_case.dart';
import '../../data/drafts/meal_draft.dart';

part 'add_meal_controller.g.dart';

@riverpod
class AddMealControllerNotifier extends _$AddMealControllerNotifier {
  @override
  Future<Meal?> build() async {
    return null;
  }

  Future<Meal> addMeal(MealDraft draft) async {
    state = const AsyncLoading();

    try {
      final useCase = ref.read(addMealUseCaseProvider);
      final meal = await useCase.call(draft);
      state = AsyncData(meal);
      return meal;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
