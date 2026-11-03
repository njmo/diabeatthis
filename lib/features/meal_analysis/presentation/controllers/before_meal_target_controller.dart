import '../../../../core/domain/model/temporary_target.dart';
import '../../domain/models/before_meal_context.dart';
import '../../domain/use_cases/select_preceding_target_use_case.dart';

class BeforeMealTargetController {
  const BeforeMealTargetController();

  String? type(TemporaryTarget target) =>
      SelectPrecedingTargetUseCase.inferredType(target);

  ({TemporaryTarget target, DateTime end, bool active})? build(
    BeforeMealContext data,
  ) => const SelectPrecedingTargetUseCase()(data.treatments, data.asOf);
}
