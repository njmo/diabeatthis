import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../meals/common/models/meal_wizard_assignment.dart';
import '../models/day_analysis_window.dart';
import '../models/day_meal_review_entry.dart';
import '../models/day_recorded_meal.dart';

class BuildDayMealReviewUseCase {
  final Future<List<Treatment>> Function(DateTime, DateTime) loadTreatments;
  final Future<List<MealWizardAssignment>> Function(List<BolusWizard>)
  loadAssignments;
  final Future<List<DayRecordedMeal>> Function(DateTime, DateTime, List<int>)
  loadMeals;
  final DateTime Function() now;
  final Duration timeout;

  const BuildDayMealReviewUseCase({
    required this.loadTreatments,
    required this.loadAssignments,
    required this.loadMeals,
    required this.now,
    this.timeout = const Duration(seconds: 15),
  });

  Future<List<DayMealReviewEntry>> call(DateTime date) async {
    final window = DayAnalysisWindow(now: now(), date: date);
    final treatments = await loadTreatments(
      window.start,
      window.queryEnd,
    ).timeout(timeout);
    final wizards =
        treatments
            .whereType<BolusWizard>()
            .where(
              (w) =>
                  w.isValid &&
                  !w.createdAt.isBefore(window.start) &&
                  !w.createdAt.isAfter(window.queryEnd),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final assignments = await loadAssignments(wizards).timeout(timeout);
    final meals = await loadMeals(
      window.start,
      window.queryEnd,
      assignments
          .where((a) => !a.dismissed)
          .map((a) => a.mealId)
          .toSet()
          .toList(),
    ).timeout(timeout);
    final byMeal = {for (final meal in meals) meal.id: <BolusWizard>[]};
    final linksByMeal = {
      for (final meal in meals) meal.id: <MealWizardAssignment>[],
    };
    final result = <DayMealReviewEntry>[];
    for (final wizard in wizards) {
      final links = assignments
          .where((a) => !a.dismissed && a.matches(wizard))
          .toList();
      if (links.length > 1) {
        throw StateError('Conflicting wizard assignments');
      }
      final link = links.firstOrNull;
      if (link != null) {
        if (!byMeal.containsKey(link.mealId)) {
          throw StateError('Linked meal is unavailable');
        }
        byMeal[link.mealId]!.add(wizard);
        linksByMeal[link.mealId]!.add(link);
      } else {
        result.add(
          DayMealReviewEntry(
            meal: null,
            wizards: [wizard],
            assignments: [],
            automaticMatchingBlocked: assignments.any(
              (a) => a.dismissed && a.matches(wizard),
            ),
          ),
        );
      }
    }
    result.addAll(
      meals.map(
        (meal) => DayMealReviewEntry(
          meal: meal,
          wizards: byMeal[meal.id]!,
          assignments: linksByMeal[meal.id]!,
        ),
      ),
    );
    result.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return List.unmodifiable(result);
  }
}
