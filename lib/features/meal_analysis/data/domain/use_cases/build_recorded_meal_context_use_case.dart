import '../../../../meals/common/models/meal_wizard_assignment.dart';
import '../../../../meals/data/mappers/meal_ai_facts_mapper.dart';
import '../../../../meals/data/models/meal_details_data.dart';
import '../../../domain/models/before_meal_context.dart';
import '../../../domain/models/meal_ai_context.dart';
import '../../../domain/models/meal_ai_facts.dart';
import '../../../domain/models/meal_outcome_context.dart';

/// A single recorded meal, shared by retrospective analysis and advisor history.
class BuildRecordedMealContextUseCase {
  final Future<MealDetailsData> Function(int) loadDetails;
  final Future<List<MealWizardAssignment>> Function(int) loadAssignments;
  final Future<BeforeMealContext> Function(MealAiFacts) loadBefore;
  final Future<MealOutcomeContext?> Function(MealDetailsData, DateTime?)
  loadOutcome;
  final DateTime Function() now;

  const BuildRecordedMealContextUseCase({
    required this.loadDetails,
    required this.loadAssignments,
    required this.loadBefore,
    required this.loadOutcome,
    required this.now,
  });

  Future<MealAiObservation> call(int mealId, [DateTime? cutoff]) async {
    final details = await loadDetails(mealId);
    List<MealWizardAssignment>? assignments;
    try {
      assignments = await loadAssignments(mealId);
    } catch (_) {
      // Unknown assignments must not be inferred from temporal proximity.
    }
    final facts = const MealAiFactsMapper().map(
      details,
      cutoff: cutoff,
      wizardAssignments: assignments,
    );
    if (facts.mealId != mealId || facts.eatenAt.isAfter(cutoff ?? now())) {
      throw StateError('Invalid recorded meal');
    }
    final before = await loadBefore(facts);
    MealOutcomeContext? outcome;
    try {
      outcome = await loadOutcome(details, cutoff);
    } catch (_) {
      // Missing outcomes remain explicit; preceding evidence stays usable.
    }
    return MealAiObservation(meal: facts, before: before, outcome: outcome);
  }
}
