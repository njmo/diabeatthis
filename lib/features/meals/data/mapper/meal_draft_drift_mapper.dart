import 'package:drift/drift.dart' as d;

import '../../../../core/drift/entity/meal.dart';
import '../drafts/meal_draft.dart';

extension MealDraftToCompanion on MealDraft {
  MealCompanion toCompanion() {
    return MealCompanion(
      name: d.Value(name),
      plannedAt: d.Value(plannedAt.millisecondsSinceEpoch),
      purpose: d.Value(purpose.storageValue),
      status: d.Value(status),
      notes: d.Value(notes),
      mealTemplateId: d.Value(mealTemplateId),
      basedOnMealId: d.Value(basedOnMealId),
    );
  }
}
