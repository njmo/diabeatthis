import '../../../../common/monitoring/is_temporary_target_active.dart';
import '../../../../common/temporary_targets/temp_target_policy.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/temporary_target.dart';

class AttachMealToTargetUseCase {
  const AttachMealToTargetUseCase({
    required this.now,
    required this.currentTarget,
    required this.loadMeal,
    required this.saveLink,
  });
  final DateTime Function() now;
  final TemporaryTarget? Function() currentTarget;
  final Future<Meal?> Function(int id) loadMeal;
  final Future<void> Function(TemporaryTarget target, int mealId) saveLink;

  Future<void> call(TemporaryTarget target, int mealId) async {
    final meal = await loadMeal(mealId);
    if (meal == null || meal.purpose != MealPurpose.meal) {
      throw StateError('The selected meal no longer exists');
    }
    if (target.targetTop != TempTargetPolicy.mealTarget ||
        currentTarget() != target ||
        !isTemporaryTargetActive(target, at: now())) {
      throw StateError('The meal target changed or expired');
    }
    await saveLink(target, mealId);
  }
}
