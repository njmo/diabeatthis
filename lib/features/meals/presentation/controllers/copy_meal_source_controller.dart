import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';

part 'copy_meal_source_controller.g.dart';

@riverpod
class CopyMealSourceController extends _$CopyMealSourceController {
  int _requestId = 0;

  @override
  FutureOr<void> build() {
    ref.onDispose(cancelPendingCopy);
  }

  void cancelPendingCopy() => _requestId++;

  Future<bool> copyFromSource(CopiedMealType source) async {
    final requestId = ++_requestId;
    state = const AsyncLoading();
    try {
      final ingredients = await switch (source) {
        CopiedMealFromTemplate() => ref.read(
          getMealIngredientsDraftForMealTemplateProvider(source.id).future,
        ),
        CopiedMealFromMeal() => ref.read(
          getMealIngredientsDraftForMealProvider(source.id).future,
        ),
      };
      if (!ref.mounted || requestId != _requestId) {
        return false;
      }
      ref.read(mealDraftProvider.notifier).applySource(source, ingredients);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      if (!ref.mounted || requestId != _requestId) {
        return false;
      }
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
