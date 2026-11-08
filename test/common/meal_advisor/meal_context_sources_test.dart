import 'package:diabeatthis/common/meal_advisor/context/caregiver_meal_context_history.dart';
import 'package:diabeatthis/common/meal_advisor/context/meal_decision_activity_context.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 8, 12);
  test('target cancellation clips the previous grey duration window', () {
    TemporaryTarget target(DateTime at, int duration) => TemporaryTarget(
      nightscoutId: '$at',
      createdAt: at,
      duration: duration,
      durationInMiliseconds: duration * 60000,
      targetBottom: 100,
      targetTop: 110,
    );
    final history = CaregiverMealContextHistory(
      asOf: now,
      glucose: const [],
      devices: const [],
      treatments: [
        target(now.subtract(const Duration(minutes: 20)), 60),
        target(now.subtract(const Duration(minutes: 5)), 0),
      ],
    );
    expect(history.targets, hasLength(1));
    expect(
      history.targets.single.end,
      now.subtract(const Duration(minutes: 5)),
    );
  });
  test(
    'activity context includes upcoming and recent logs but not skipped or remote future sessions',
    () {
      Map<String, dynamic> row(
        String kind,
        int id,
        Map<String, dynamic> payload,
      ) => {
        'kind': kind,
        'id': '$id',
        'payload': {'id': id, ...payload},
      };
      final rows = [
        row('activities', 1, {'name': 'Training'}),
        row('activityLogs', 2, {
          'activity_id': 1,
          'started_at': now
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'ended_at': now
              .subtract(const Duration(minutes: 20))
              .millisecondsSinceEpoch,
        }),
        for (final entry in [
          (3, 30, 'planned'),
          (4, 40, 'skipped'),
          (5, 600, 'planned'),
        ])
          row('activityOccurrences', entry.$1, {
            'activity_id': 1,
            'started_at': now
                .add(Duration(minutes: entry.$2))
                .millisecondsSinceEpoch,
            'status': entry.$3,
          }),
      ];
      final context = MealDecisionActivityContext.fromRows(rows, now);
      expect(context.map((entry) => entry.kind), [
        'activityLogs',
        'activities',
      ]);
      expect(context.map((entry) => entry.id), [2, 1]);
    },
  );
}
