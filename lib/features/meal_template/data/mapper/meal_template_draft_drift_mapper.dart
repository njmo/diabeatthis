import 'package:drift/drift.dart' as d;

import '../../../../core/drift/database_impl.dart';
import '../drafts/template_meal_draft.dart';

extension MealDraftTemplateToCompanion on MealTemplateDraft {
  MealTemplateCompanion toCompanion() {
    return MealTemplateCompanion(
      name: d.Value(name),
      notes: notes == null ? d.Value.absent() : d.Value(notes),
      isFavorite: d.Value(isFavorite),
      createdFromMealId: d.Value(createdFromMealId),
    );
  }
}
