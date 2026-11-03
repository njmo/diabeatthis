import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_target_preparation_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_temporary_target_periods_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 11, 3, 12);
  TemporaryTarget target(int offset, {int value = 90, int duration = 60, bool valid = true}) => TemporaryTarget(
    nightscoutId: '$offset', createdAt: at.add(Duration(minutes: offset)), durationInMiliseconds: duration * 60000,
    duration: duration, targetBottom: value, targetTop: value, isValid: valid);
  const build = BuildMealTargetPreparationUseCase();

  test('a recorded meal start gets exact preparation lead time without selecting a future target', () {
    final result = build(treatments: [target(-20), target(5)], recordedMealStart: at)!;
    expect(result.leadTime, const Duration(minutes: 20));
    expect(result.mealStartedAt, at);
    expect(result.target.createdAt, at.subtract(const Duration(minutes: 20)));
  });

  test('missing history or recorded start, non-meal targets and ended targets never imply preparation', () {
    expect(build(treatments: null, recordedMealStart: at), isNull);
    expect(build(treatments: [target(-20)], recordedMealStart: null), isNull);
    expect(build(treatments: [target(-20, value: 140)], recordedMealStart: at), isNull);
    expect(build(treatments: [target(-60)], recordedMealStart: at), isNull);
    expect(build(treatments: [target(0)], recordedMealStart: at), isNull);
    expect(build(treatments: [target(-20), target(-5, duration: 0)], recordedMealStart: at), isNull);
    expect(build(treatments: [target(-20), target(-5, valid: false)], recordedMealStart: at), isNull);
    expect(build(treatments: [target(-20), target(-5, value: 160)], recordedMealStart: at), isNull);
  });

  test('target periods stop at cancellation and replacement barriers', () {
    final periods = const BuildTemporaryTargetPeriodsUseCase()([
      target(-40), target(-20, value: 140), target(-5, duration: 0),
    ]);
    expect(periods, hasLength(2));
    expect(periods.first.end, at.subtract(const Duration(minutes: 20)));
    expect(periods.last.end, at.subtract(const Duration(minutes: 5)));
  });
}
