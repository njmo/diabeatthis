import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/activity.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_dose_suggestion.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_windows.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/get_meal_activity_advice_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mealAt = DateTime(2026, 11, 3, 14);
  MealDoseActivity activity({
    int start = 30,
    int? end,
    int pre = 80,
    int post = 70,
    String name = 'Walk',
    bool unconfirmed = false,
  }) => (
    activity: Activity(
      id: 1,
      name: name,
      percentagePre: pre,
      percentagePost: post,
      durationMinutes: 30,
    ),
    startedAt: mealAt.add(Duration(minutes: start)),
    endedAt: end == null ? null : mealAt.add(Duration(minutes: end)),
    isUnconfirmed: unconfirmed,
  );

  GetMealActivityAdviceUseCase useCase(
    List<MealDoseActivity> entries, {
    MealActivityWindows windows = const MealActivityWindows(),
  }) => GetMealActivityAdviceUseCase(
    loadWindows: () async => windows,
    loadActivities: (start, end) async {
      expect(start, mealAt.subtract(Duration(minutes: windows.pastMinutes)));
      expect(end, mealAt.add(Duration(minutes: windows.futureMinutes)));
      return entries;
    },
    onError: (error, _) => fail('$error'),
  );

  test(
    'uses configured bolus percentage directly, not 100 minus percentage',
    () async {
      final result = await useCase([activity(pre: 80)])(mealAt: mealAt);
      expect(result!.dosePercent, 80);
      expect(result.phase, MealActivityPhase.upcoming);
      expect(result.activityName, 'Walk');
    },
  );

  for (final scenario in [
    (minute: 59, eligible: true),
    (minute: 60, eligible: true),
    (minute: 61, eligible: false),
  ]) {
    test('future start at ${scenario.minute} minutes', () async {
      final result = await useCase([activity(start: scenario.minute)])(
        mealAt: mealAt,
      );
      expect(result != null, scenario.eligible);
    });
  }
  for (final scenario in [
    (minute: -119, eligible: true),
    (minute: -120, eligible: true),
    (minute: -121, eligible: false),
  ]) {
    test(
      'past window uses END at ${scenario.minute} minutes, not start',
      () async {
        final result = await useCase([
          activity(start: -240, end: scenario.minute),
        ])(mealAt: mealAt);
        expect(result != null, scenario.eligible);
        if (result != null) {
          expect(result.dosePercent, 70);
          expect(result.phase, MealActivityPhase.completed);
        }
      },
    );
  }

  test('second precision is preserved at both boundaries', () async {
    final future = activity(start: 60);
    final past = activity(start: -240, end: -120);
    final tooLate = (
      activity: future.activity,
      startedAt: future.startedAt.add(const Duration(milliseconds: 1)),
      endedAt: null,
      isUnconfirmed: false,
    );
    final tooOld = (
      activity: past.activity,
      startedAt: past.startedAt,
      endedAt: past.endedAt!.subtract(const Duration(milliseconds: 1)),
      isUnconfirmed: false,
    );
    expect(await useCase([tooLate, tooOld])(mealAt: mealAt), isNull);
  });

  test(
    'ongoing activity remains relevant even if it started before the past window',
    () async {
      final result = await useCase([activity(start: -300)])(mealAt: mealAt);
      expect(result!.phase, MealActivityPhase.ongoing);
      expect(result.dosePercent, 80);
    },
  );

  test('activity starting exactly at meal is ongoing and uses pre', () async {
    final result = await useCase([activity(start: 0)])(mealAt: mealAt);
    expect(result!.phase, MealActivityPhase.ongoing);
    expect(result.dosePercent, 80);
  });

  test('activity ending exactly at meal uses post', () async {
    final result = await useCase([activity(start: -30, end: 0)])(
      mealAt: mealAt,
    );
    expect(result!.phase, MealActivityPhase.completed);
    expect(result.dosePercent, 70);
  });

  test('a known future end still means ongoing at meal', () async {
    final result = await useCase([activity(start: -30, end: 20)])(
      mealAt: mealAt,
    );
    expect(result!.phase, MealActivityPhase.ongoing);
  });

  test(
    'latest eligible start wins regardless of input order; percentages do not add',
    () async {
      final entries = [
        activity(start: 40, pre: 90, name: 'Latest'),
        activity(start: -90, end: -30, post: 60),
        activity(start: 15, pre: 50),
        activity(start: 90, pre: 40, name: 'Outside'),
      ];
      for (final list in [entries, entries.reversed.toList()]) {
        final result = await useCase(list)(mealAt: mealAt);
        expect(result!.activityName, 'Latest');
        expect(result.dosePercent, 90);
      }
    },
  );

  test('latest completed activity is selected by start, not end', () async {
    final result = await useCase([
      activity(start: -150, end: -10, name: 'Older'),
      activity(start: -60, end: -30, name: 'Latest', post: 85),
    ])(mealAt: mealAt);
    expect(result!.activityName, 'Latest');
    expect(result.dosePercent, 85);
  });

  test(
    'unconfirmed plans cannot become evidence of ongoing or past activity',
    () async {
      expect(
        await useCase([activity(start: -30, unconfirmed: true)])(
          mealAt: mealAt,
        ),
        isNull,
      );
      expect(
        await useCase([activity(start: 30, unconfirmed: true)])(mealAt: mealAt),
        isNotNull,
      );
    },
  );

  test('custom windows expand and restrict the default windows', () async {
    expect(
      await useCase([
        activity(start: 90),
      ], windows: const MealActivityWindows(futureMinutes: 90))(mealAt: mealAt),
      isNotNull,
    );
    expect(
      await useCase([
        activity(start: -90, end: -45),
      ], windows: const MealActivityWindows(pastMinutes: 30))(mealAt: mealAt),
      isNull,
    );
  });

  test(
    'disabled past/future windows exclude those phases but preserve ongoing',
    () async {
      const windows = MealActivityWindows(pastMinutes: 0, futureMinutes: 0);
      expect(
        await useCase([
          activity(start: 1),
          activity(start: -30, end: -1),
        ], windows: windows)(mealAt: mealAt),
        isNull,
      );
      expect(
        (await useCase([activity(start: -30)], windows: windows)(
          mealAt: mealAt,
        ))!.phase,
        MealActivityPhase.ongoing,
      );
    },
  );

  test(
    'missing or invalid percentage on latest activity does not fall back to older activity',
    () async {
      for (final percent in [0, -1, 101]) {
        expect(
          await useCase([
            activity(start: 30, pre: percent),
            activity(start: 10),
          ])(mealAt: mealAt),
          isNull,
        );
      }
      expect(
        (await useCase([activity(pre: 100)])(mealAt: mealAt))!.dosePercent,
        100,
      );
    },
  );

  test('invalid intervals are excluded', () async {
    expect(
      await useCase([activity(start: -10, end: -20)])(mealAt: mealAt),
      isNull,
    );
  });

  test(
    'history failure reports error and returns no suggestion, not a guessed dose',
    () async {
      final errors = <Object>[];
      final uc = GetMealActivityAdviceUseCase(
        loadWindows: () async => const MealActivityWindows(),
        loadActivities: (_, _) async => throw StateError('offline'),
        onError: (error, _) => errors.add(error),
      );
      expect(await uc(mealAt: mealAt), isNull);
      expect(errors.single, isA<StateError>());
    },
  );

  test(
    'stored meal time anchors delayed handoff instead of current clock time',
    () async {
      final uc = GetMealActivityAdviceUseCase(
        loadMealTime: (id) async {
          expect(id, 7);
          return mealAt;
        },
        loadWindows: () async => const MealActivityWindows(),
        loadActivities: (start, _) async {
          expect(start, mealAt.subtract(const Duration(hours: 2)));
          return [activity(start: 30)];
        },
        onError: (error, _) => fail('$error'),
      );
      final result = await withClock(
        Clock.fixed(mealAt.add(const Duration(hours: 3))),
        () => uc(mealId: 7),
      );
      expect(result!.phase, MealActivityPhase.upcoming);
    },
  );
}
