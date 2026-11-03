import '../../../../common/temporary_targets/temp_target_policy.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/domain/model/treatment_base.dart';
import 'build_temporary_target_periods_use_case.dart';

class SelectPrecedingTargetUseCase {
  const SelectPrecedingTargetUseCase();

  static String? inferredType(TemporaryTarget target) =>
      target.targetBottom != target.targetTop
      ? null
      : switch (target.targetBottom) {
          TempTargetPolicy.mealTarget => 'Meal',
          TempTargetPolicy.activityTarget => 'Activity',
          _ => null,
        };

  ({TemporaryTarget target, DateTime end, bool active})? call(
    List<Treatment>? treatments,
    DateTime at,
  ) {
    if (treatments == null) return null;
    final observed = treatments
        .whereType<TemporaryTarget>()
        .where((entry) => !entry.createdAt.isAfter(at))
        .toList();
    final periods = const BuildTemporaryTargetPeriodsUseCase()(observed);
    for (final period in periods.reversed) {
      if (period.end.isBefore(at.subtract(const Duration(hours: 3)))) {
        return null;
      }
      return (
        target: period.target,
        end: period.end,
        active: period.end.isAfter(at),
      );
    }
    return null;
  }
}
