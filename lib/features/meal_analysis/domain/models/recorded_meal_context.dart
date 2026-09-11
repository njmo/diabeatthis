import '../../../../core/domain/model/meal_snapshot.dart';
import 'meal_composition.dart';

class RecordedMealContext {
  final int mealId;
  final String name;
  final DateTime eatenAt;

  /// Null if no snapshot unchanged since the cutoff can be recovered.
  final MealSnapshot? snapshot;
  final MealComposition? composition;
  const RecordedMealContext({
    required this.mealId,
    required this.name,
    required this.eatenAt,
    required this.snapshot,
    this.composition,
  });
}
