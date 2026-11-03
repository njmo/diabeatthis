import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../models/temporary_target_period.dart';

/// Stops, replacements and invalid records are barriers to older targets.
class BuildTemporaryTargetPeriodsUseCase {
  const BuildTemporaryTargetPeriodsUseCase();

  List<TemporaryTargetPeriod> call(List<Treatment> treatments) {
    final targets = treatments.whereType<TemporaryTarget>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final result = <TemporaryTargetPeriod>[];
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      if (!target.isValid ||
          target.duration <= 0 ||
          target.targetBottom <= 0 ||
          target.targetTop < target.targetBottom) {
        continue;
      }
      var end = target.createdAt.add(Duration(minutes: target.duration));
      if (i + 1 < targets.length && targets[i + 1].createdAt.isBefore(end)) {
        end = targets[i + 1].createdAt;
      }
      if (end.isAfter(target.createdAt)) {
        result.add(TemporaryTargetPeriod(target: target, end: end));
      }
    }
    return List.unmodifiable(result);
  }
}
