import 'package:drift/drift.dart' as d;

import '../../../../core/drift/entity/meal.dart';
import '../drafts/meal_draft.dart';

extension MealDraftToCompanion on MealDraft {
  MealCompanion toCompanion() {
    return MealCompanion(
        name: d.Value(name),
        plannedAt: d.Value(plannedAt.millisecondsSinceEpoch),
        carbsCounted: d.Value(carbs)
    );
  }
}
