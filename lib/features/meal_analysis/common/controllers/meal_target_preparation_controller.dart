import '../../../../core/domain/model/treatment_base.dart';
import '../../domain/models/meal_target_preparation.dart';
import '../../domain/models/temporary_target_period.dart';
import '../../domain/use_cases/build_meal_target_preparation_use_case.dart';
import '../../domain/use_cases/build_temporary_target_periods_use_case.dart';

class MealTargetPreparationController {
  const MealTargetPreparationController({
    this.buildPreparation = const BuildMealTargetPreparationUseCase(),
  });
  final BuildMealTargetPreparationUseCase buildPreparation;

  List<TemporaryTargetPeriod> periods(List<Treatment> treatments) =>
      const BuildTemporaryTargetPeriodsUseCase()(treatments);

  MealTargetPreparation? build({
    required List<Treatment>? treatments,
    required DateTime? recordedMealStart,
  }) => buildPreparation(
    treatments: treatments,
    recordedMealStart: recordedMealStart,
  );
}
