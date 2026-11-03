import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/temporary_target.dart';

class LoadMealTargetCandidatesUseCase {
  const LoadMealTargetCandidatesUseCase({required this.loadMeals});
  final Future<List<Meal>> Function(DateTime from, DateTime until) loadMeals;

  Future<List<Meal>> call(TemporaryTarget target) async {
    final meals = await loadMeals(
      target.createdAt.subtract(const Duration(days: 1)),
      target.createdAt.add(const Duration(days: 1)),
    );
    final candidates = meals
        .where(
          (meal) => meal.purpose == MealPurpose.meal && meal.plannedAt != null,
        )
        .toList();
    candidates.sort(
      (a, b) => a.plannedAt!
          .difference(target.createdAt)
          .abs()
          .compareTo(b.plannedAt!.difference(target.createdAt).abs()),
    );
    return candidates;
  }
}
