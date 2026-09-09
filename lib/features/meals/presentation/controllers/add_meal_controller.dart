import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../data/domain/use_cases/add_meal_use_case.dart';
import '../../data/domain/use_cases/log_retrospective_meal_use_case.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/models/retrospective_meal_timing.dart';
import 'copy_meal_source_controller.dart';

part 'add_meal_controller.g.dart';

@riverpod
class AddMealControllerNotifier extends _$AddMealControllerNotifier {
  @override
  Future<Meal?> build() async {
    return null;
  }

  Future<Meal> addMeal(
    MealDraft draft, {
    RetrospectiveMealTiming? retrospective,
  }) async {
    if (ref.read(copyMealSourceControllerProvider).isLoading) {
      throw StateError('Cannot save a meal while its source is loading');
    }
    final keepAliveLink = ref.keepAlive();
    state = const AsyncLoading();

    try {
      final useCase = ref.read(addMealUseCaseProvider);
      final meal = retrospective == null
          ? await useCase.call(draft)
          : await LogRetrospectiveMealUseCase(ref).call(draft, retrospective);
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
