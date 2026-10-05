import 'package:diabeatthis/core/domain/model/stress_event.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/load_low_treatment_observation_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_activity_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 12);
  MealActivityContext activity(int id, int minutes, {DateTime? endedAt}) =>
      MealActivityContext(
        logId: id,
        name: 'Activity $id',
        startedAt: now.add(Duration(minutes: minutes)),
        endedAt: endedAt,
        recordedAt: now.subtract(const Duration(days: 1)),
        plannedDurationMinutes: 45,
        percentagePre: 50,
        percentagePost: 70,
      );
  StressEvent stress(int minutes, {DateTime? end}) => StressEvent(
    occurredAt: now.add(Duration(minutes: minutes)),
    endedAt: end,
    source: 'manual',
    stressLevel: StressLevel.high,
  );

  test(
    'nearest upcoming activity and timestamped stress remain observational context',
    () async {
      final result = await LoadLowTreatmentObservationContextUseCase(
        loadActivities: (s, e, c) async => [
          activity(1, -30),
          activity(2, 45),
          activity(3, 120),
          activity(4, 15),
        ],
        loadStress: (s, e) async => [stress(-60), stress(-15), stress(5)],
      )(now);
      expect(result.activityName, 'Activity 4');
      expect(result.activityStartsAt, now.add(const Duration(minutes: 15)));
      expect(result.stressLevel, StressLevel.high);
      expect(
        result.stressObservedAt,
        now.subtract(const Duration(minutes: 15)),
      );
    },
  );

  test(
    'finished activities and old unbounded stress are not presented as current context',
    () async {
      final result = await LoadLowTreatmentObservationContextUseCase(
        loadActivities: (s, e, c) async => [activity(1, -60, endedAt: now)],
        loadStress: (s, e) async => [stress(-240)],
      )(now);
      expect(result.activityName, isNull);
      expect(result.stressLevel, isNull);
    },
  );

  test(
    'an explicitly ongoing stress interval may start before the lookback',
    () async {
      final result = await LoadLowTreatmentObservationContextUseCase(
        loadActivities: (s, e, c) async => [],
        loadStress: (s, e) async => [
          stress(-240, end: now.add(const Duration(hours: 1))),
        ],
      )(now);
      expect(result.stressObservedAt, now.subtract(const Duration(hours: 4)));
    },
  );

  test('one unavailable context source does not hide the other', () async {
    final result = await LoadLowTreatmentObservationContextUseCase(
      loadActivities: (s, e, c) async => throw StateError('Unavailable'),
      loadStress: (s, e) async => [stress(-15)],
    )(now);
    expect(result.activityName, isNull);
    expect(result.stressLevel, StressLevel.high);
  });
}
