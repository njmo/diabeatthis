import '../../meals/data/drafts/meal_draft.dart';

abstract interface class MealPhotoDraftWriter {
  Future<int> write(MealDraft draft);
}
