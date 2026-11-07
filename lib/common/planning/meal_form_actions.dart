import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/data/models/retrospective_meal_timing.dart';
import '../../features/meals/presentation/controllers/add_meal_controller.dart';
import '../../features/meals/presentation/widgets/add_meal_ingredient.dart';
import '../l10n/language.dart';

class MealFormActions extends ChangeNotifier {
  bool get showNotes => false;
  int get planningHorizonDays => 5;
  bool get canCopy => true;
  bool get allowLocalLookups => true;
  bool canContinue(MealDraft draft) => true;
  bool get saving => false;
  String? hint(BuildContext context, MealDraft draft) => null;
  String failureMessage(BuildContext context, Object error) =>
      context.lang.mealIngredientsLoadError(error);
  Future<MealIngredientsDraft?> pickIngredient(
    BuildContext context,
    WidgetRef ref, {
    MealIngredientsDraft? initial,
  }) => showAddMealIngredientSheet(
    context: context,
    ref: ref,
    initialDraft: initial,
  );
  Future<Object?> save(
    WidgetRef ref,
    AppLocalizations language, {
    RetrospectiveMealTiming? retrospective,
  }) => ref
      .read(addMealControllerProvider.notifier)
      .saveCurrentDraft(language, retrospective: retrospective);
  void close(BuildContext context, Object? result) =>
      context.router.pop(result);
}

final mealFormActionsProvider = Provider.autoDispose<MealFormActions>((ref) {
  final actions = MealFormActions();
  ref.onDispose(actions.dispose);
  return actions;
});
