import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_category.dart';
import '../../data/domain/use_cases/update_meal_category_use_case.dart';
import 'meal_details_controller.dart';

part 'meal_category_controller.g.dart';

@riverpod
class MealCategoryController extends _$MealCategoryController {
  @override
  FutureOr<void> build(int mealId) {}

  Future<MealCategory?> load() => UpdateMealCategoryUseCase(ref).load(mealId);

  Future<void> saveCategory(
    MealCategory category,
    AppLocalizations language,
  ) async {
    if (state.isLoading) return;
    final link = ref.keepAlive();
    state = const AsyncLoading();
    try {
      await UpdateMealCategoryUseCase(ref).call(mealId, category, language);
      ref.invalidate(mealDetailsControllerProvider(mealId));
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    } finally {
      link.close();
    }
  }
}
