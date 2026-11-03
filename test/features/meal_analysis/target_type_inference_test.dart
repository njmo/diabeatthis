import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/select_preceding_target_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TemporaryTarget target(int bottom, int top) => TemporaryTarget(
    nightscoutId: 'target',
    createdAt: DateTime(2026, 11, 3, 12),
    durationInMiliseconds: 3600000,
    duration: 60,
    targetBottom: bottom,
    targetTop: top,
  );
  test('recognizes only exact known target values', () {
    expect(SelectPrecedingTargetUseCase.inferredType(target(90, 90)), 'Meal');
    expect(
      SelectPrecedingTargetUseCase.inferredType(target(140, 140)),
      'Activity',
    );
    expect(SelectPrecedingTargetUseCase.inferredType(target(90, 140)), isNull);
    expect(SelectPrecedingTargetUseCase.inferredType(target(100, 100)), isNull);
  });
}
