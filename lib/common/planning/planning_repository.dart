import '../../core/domain/model/meal.dart';
import '../../features/activity/data/drafts/activity_entry_action.dart';
import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/data/models/retrospective_meal_timing.dart';
import '../l10n/language.dart';

/// Domain writes; a cloud proposal is not a locally committed child record.
abstract interface class PlanningRepository {
  Future<Meal?> insertMeal(
    MealDraft draft, {
    RetrospectiveMealTiming? retrospective,
  });
  Future<Meal?> saveMeal(
    MealDraft draft, {
    required bool automaticName,
    required AppLocalizations language,
    RetrospectiveMealTiming? retrospective,
  });
  Future<int?> saveActivity(DashboardActivityAction action);
  Future<void> proposeMeal(Map<String, dynamic> values);
  Future<void> moveActivity(int occurrenceId, DateTime start);
}
