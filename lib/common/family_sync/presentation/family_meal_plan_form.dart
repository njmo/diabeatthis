import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/meals/data/domain/use_cases/calculate_meal_draft_nutrition_use_case.dart';
import '../../../features/meals/data/domain/use_cases/find_dominant_meal_ingredients_use_case.dart';
import '../../../features/meals/data/drafts/meal_draft.dart';
import '../../../features/meals/data/providers/copied_meal_provider.dart';
import '../../../features/meals/data/providers/meal_draft_nutrition_totals_provider.dart';
import '../../../features/meals/data/providers/meal_draft_provider.dart';
import '../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../features/meals/data/providers/meal_name_ingredients_provider.dart';
import '../../../features/meals/presentation/controllers/copy_meal_source_controller.dart';
import '../../../features/meals/presentation/screens/add_meal_page.dart';
import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../l10n/language.dart';
import '../../nutrition/meal_nutrition_totals.dart';
import '../../planning/caregiver_meal_form_actions.dart';
import '../../planning/family_meal_copy_source.dart';
import '../../planning/family_meal_draft.dart';
import '../../planning/firebase_planning_repository.dart';
import '../../planning/meal_form_actions.dart';
import '../../planning/planning_repository_provider.dart';

/// Source binding only: the actual editor is the child's AddMealPage.
class FamilyMealPlanForm extends ConsumerStatefulWidget {
  const FamilyMealPlanForm({
    super.key,
    required this.rows,
    required this.onSubmit,
    this.initial,
  });
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? initial;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  @override
  ConsumerState<FamilyMealPlanForm> createState() => FamilyMealPlanFormState();
}

class FamilyMealPlanFormState extends ConsumerState<FamilyMealPlanForm> {
  CaregiverMealFormActions? initializedActions;
  CaregiverMealFormActions get actions =>
      initializedActions ??= CaregiverMealFormActions(
        rows: widget.rows,
        catalog: ref.read(catalogRepositoryProvider),
      );
  late final draft = familyMealDraft(widget.rows, widget.initial);
  late final repository = FirebasePlanningRepository(
    submit: (_, _, values) => widget.onSubmit(values),
  );
  @override
  void dispose() {
    initializedActions?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MealDraft initial;
    try {
      initial = draft;
    } on StateError {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.lang.familyPlanWaitingForChild)),
      );
    }
    return ProviderScope(
      overrides: [
        planningRepositoryProvider.overrideWithValue(repository),
        mealFormActionsProvider.overrideWithValue(actions),
        copyMealSourceControllerProvider.overrideWith(
          CopyMealSourceController.new,
        ),
        copiedFromMealByQueryProvider.overrideWith(
          (ref, query) async => FamilyMealCopySource(widget.rows).search(query),
        ),
        getMealIngredientsDraftForMealProvider.overrideWith(
          (ref, id) async => FamilyMealCopySource(widget.rows).ingredients(id),
        ),
        mealDraftProvider.overrideWith(
          () => MealDraftNotifier(initialDraft: initial),
        ),
        mealDraftIngredientsProvider.overrideWith(
          (ref) => ref.watch(mealDraftProvider).mealIngredients,
        ),
        mealNameIngredientsProvider.overrideWith(
          (ref) => FindDominantMealIngredientsUseCase.withResolver(
            (item) async =>
                item.amount *
                (item.recordedGramsPerAmount ?? item.ingredientPortion.amount),
          ).call(ref.watch(mealDraftProvider).mealIngredients),
        ),
        mealDraftNutritionTotalsProvider.overrideWith(
          (ref) async => MealNutritionTotals.fromMacroSummary(
            await CalculateMealDraftNutritionUseCase(
              resolveGrams: (item) async =>
                  item.amount *
                  (item.recordedGramsPerAmount ??
                      item.ingredientPortion.amount),
            ).call(ref.watch(mealDraftProvider).mealIngredients),
          ),
        ),
      ],
      child: AddMealPage(initialEatenAt: initial.plannedAt),
    );
  }
}
