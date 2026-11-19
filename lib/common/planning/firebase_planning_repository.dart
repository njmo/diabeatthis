import '../../core/domain/model/meal.dart';
import '../../features/activity/data/drafts/activity_entry_action.dart';
import '../../features/ingredients/data/drafts/ingredient_draft.dart';
import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/data/models/retrospective_meal_timing.dart';
import '../l10n/language.dart';
import 'activity_schedule_values.dart';
import 'family_activity_reference.dart';
import 'planning_repository.dart';

/// Only canonical references travel to the backend; child execution is excluded.
class FirebasePlanningRepository implements PlanningRepository {
  FirebasePlanningRepository({
    required this.submit,
    this.operation = 'createMeal',
    this.targetId,
  });
  final Future<void> Function(String type, int? targetId, Map<String, dynamic>)
  submit;
  final String operation;
  final int? targetId;
  @override
  Future<Meal?> insertMeal(
    MealDraft draft, {
    RetrospectiveMealTiming? retrospective,
  }) => saveMeal(
    draft,
    automaticName: false,
    language: lang,
    retrospective: retrospective,
  );
  @override
  Future<Meal?> saveMeal(
    MealDraft draft, {
    required bool automaticName,
    required AppLocalizations language,
    RetrospectiveMealTiming? retrospective,
  }) async {
    if (retrospective != null ||
        draft.purpose != MealPurpose.meal ||
        draft.status != 'planned') {
      throw StateError('Caregiver can only propose meal plans');
    }
    final now = DateTime.now();
    if ((draft.plannedDay != null &&
            draft.plannedDay != now.toIso8601String().split('T').first) ||
        draft.category == null ||
        draft.name.trim().isEmpty ||
        draft.name.length > 120 ||
        (draft.notes?.length ?? 0) > 2000 ||
        (draft.plannedDay == null &&
            (!draft.plannedAt.isAfter(now) ||
                !draft.plannedAt.isBefore(
                  now.add(const Duration(days: 366)),
                ))) ||
        draft.mealIngredients.isEmpty ||
        draft.mealIngredients.length > 30) {
      throw ArgumentError(language.planningInvalidDraft);
    }
    final seen = <String>{};
    final ingredients = <Map<String, dynamic>>[];
    for (final item in draft.mealIngredients) {
      final id = item.ingredient.getIngredientIdOrNull();
      if (!item.catalogReviewed ||
          (id == null &&
              (item.catalogId == null || item.catalogRevision == null))) {
        throw StateError('Review a canonical ingredient');
      }
      final factor =
          item.recordedGramsPerAmount ?? item.ingredientPortion.amount;
      if (!factor.isFinite || factor <= 0) {
        throw StateError('Missing portion conversion');
      }
      final grams = item.amount * factor;
      final identity = item.catalogId == null
          ? 'local:$id'
          : 'catalog:${item.catalogId}';
      if (!grams.isFinite ||
          grams <= 0 ||
          grams > 10000 ||
          !seen.add(identity)) {
        throw ArgumentError(language.planningInvalidDraft);
      }
      ingredients.add({
        'ingredientId': item.catalogId == null ? id : null,
        'catalogId': item.catalogId,
        'catalogRevision': item.catalogRevision,
        'grams': grams,
      });
    }
    await submit(operation, targetId, {
      'name': draft.name,
      'category': draft.category?.name,
      'plannedAt': draft.plannedDay == null
          ? draft.plannedAt.millisecondsSinceEpoch
          : null,
      if (draft.plannedDay != null) 'plannedDay': draft.plannedDay,
      'notes': draft.notes ?? '',
      'ingredients': ingredients,
    });
    return null;
  }

  @override
  Future<void> proposeMeal(Map<String, dynamic> values) =>
      submit('createMeal', null, values);
  @override
  Future<void> moveActivity(int occurrenceId, DateTime start) => submit(
    'moveActivity',
    occurrenceId,
    {'startedAt': start.millisecondsSinceEpoch},
  );
  @override
  Future<int?> saveActivity(DashboardActivityAction action) async {
    final reference = {
      ...familyActivityReference(action.activity),
      if (action.schedule != null)
        'schedule': activityScheduleValues(
          action.schedule!,
          action.activity.durationMinutes,
        ),
    };
    final now = DateTime.now();
    final end = action.endedAt;
    if (!action.isScheduled) {
      if (action.startedAt.isAfter(now.add(const Duration(seconds: 30)))) {
        throw StateError('An immediate activity cannot start in the future');
      }
      if (end != null) {
        if (!end.isAfter(action.startedAt) ||
            end.isAfter(now) ||
            end.difference(action.startedAt).inMinutes > 1440) {
          throw ArgumentError('Invalid historical activity interval');
        }
        await submit('logActivity', null, {
          ...reference,
          'startedAt': action.startedAt.millisecondsSinceEpoch,
          'endedAt': end.millisecondsSinceEpoch,
        });
      } else {
        await submit('startActivity', null, {
          ...reference,
          'startedAt': now.millisecondsSinceEpoch,
        });
      }
      return null;
    }
    final minutes = action.durationMinutes;
    if (end != null ||
        minutes == null ||
        minutes < 1 ||
        minutes > 1440 ||
        !action.startedAt.isAfter(now) ||
        !action.startedAt.isBefore(now.add(const Duration(days: 366)))) {
      throw ArgumentError(
        'A future start and a duration of 1–1440 minutes are required',
      );
    }
    await submit('planActivity', null, {
      ...reference,
      'startedAt': action.startedAt.millisecondsSinceEpoch,
      'durationMinutes': minutes,
    });
    return null;
  }
}
