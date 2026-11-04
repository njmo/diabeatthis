import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_name_formatter.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../drafts/meal_draft.dart';
import '../../models/retrospective_meal_timing.dart';
import 'add_meal_use_case.dart';
import 'find_dominant_meal_ingredients_use_case.dart';
import 'log_retrospective_meal_use_case.dart';

class SaveMealDraftUseCase {
  const SaveMealDraftUseCase(this.ref);
  final Ref ref;

  Future<Meal> call(
    MealDraft draft, {
    required bool automaticName,
    required AppLocalizations language,
    RetrospectiveMealTiming? retrospective,
    bool suggestMissingIcons = true,
  }) async {
    if (draft.category == null) {
      throw ArgumentError(language.mealCategoryRequired);
    }
    var prepared = draft;
    if (automaticName) {
      final ingredients = await FindDominantMealIngredientsUseCase(
        ref,
      ).call(draft.mealIngredients);
      prepared = draft.copyWith(
        name: formatAutomaticMealName(language, ingredients, draft.category),
      );
    }
    return retrospective == null
        ? ref
              .read(addMealUseCaseProvider)
              .call(prepared, suggestMissingIcons: suggestMissingIcons)
        : LogRetrospectiveMealUseCase(ref).call(prepared, retrospective);
  }
}
