import '../../../meal_analysis/domain/models/before_meal_context.dart';
import '../../../meal_analysis/domain/models/meal_ai_context.dart';
import 'meal_advisor_target.dart';

class MealAdvisorContext {
  final BeforeMealContext before;
  final MealAdvisorTarget? target;
  final DateTime builtAt;
  final List<MealAiComparison> comparisons;
  final Set<String> failures;

  /// Null means search was unavailable or not performed.
  final int? similarMatchCount;
  MealAdvisorContext({
    required this.before,
    required this.target,
    required this.builtAt,
    this.similarMatchCount,
    required List<MealAiComparison> comparisons,
    required Set<String> failures,
  }) : comparisons = List.unmodifiable(comparisons),
       failures = Set.unmodifiable(failures);
}
