import '../../../../common/temporary_targets/temp_target_policy.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../models/meal_target_preparation.dart';
import 'select_preceding_target_use_case.dart';

class BuildMealTargetPreparationUseCase {
  const BuildMealTargetPreparationUseCase({
    this.select = const SelectPrecedingTargetUseCase(),
  });
  final SelectPrecedingTargetUseCase select;

  MealTargetPreparation? call({
    required List<Treatment>? treatments,
    required DateTime? recordedMealStart,
  }) {
    if (recordedMealStart == null) return null;
    final entry = select(treatments, recordedMealStart);
    if (entry == null ||
        !entry.active ||
        entry.target.targetBottom != TempTargetPolicy.mealTarget ||
        entry.target.targetTop != TempTargetPolicy.mealTarget ||
        !entry.target.createdAt.isBefore(recordedMealStart)) {
      return null;
    }
    return MealTargetPreparation(
      target: entry.target,
      mealStartedAt: recordedMealStart,
    );
  }
}
