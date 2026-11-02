import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_time_anchor.dart';
import 'package:diabeatthis/features/meals/data/models/retrospective_meal_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('end anchor reconstructs the screenshot scenario backwards', () {
    const timing = RetrospectiveMealTiming(
      choice: ManualMealDecision(
        decision: MealDecision.bolusWaitThenEat,
        waitMinutes: 5,
      ),
      eatingMinutes: 15,
    );
    final start = timing.startFromReference(
      DateTime(2026, 11, 2, 13, 36),
      MealTimeAnchor.eatingEnd,
    );
    expect(start, DateTime(2026, 11, 2, 13, 21));
    expect(timing.bolusAt(start), DateTime(2026, 11, 2, 13, 16));
    expect(
      () => timing.validate(start, DateTime(2026, 11, 2, 13, 38)),
      returnsNormally,
    );
  });

  for (final decision in [
    MealDecision.bolusAndEatNow,
    MealDecision.bolusWaitThenEat,
    MealDecision.eatNowBolusLater,
  ]) {
    test(
      'insulin anchor stays fixed for $decision across midnight and duration edits',
      () {
        final timing = RetrospectiveMealTiming(
          choice: ManualMealDecision(
            decision: decision,
            waitMinutes: decision == MealDecision.bolusWaitThenEat ? 5 : 0,
          ),
          eatingMinutes: 15,
          bolusAfterStartMinutes: decision == MealDecision.eatNowBolusLater
              ? 20
              : 0,
        );
        final reference = DateTime(2026, 11, 2, 0, 5);
        final start = timing.startFromReference(
          reference,
          MealTimeAnchor.insulin,
        );
        expect(timing.bolusAt(start), reference);
        expect(
          timing
              .copyWith(eatingMinutes: 10)
              .startFromReference(reference, MealTimeAnchor.insulin),
          start,
        );
        expect(
          timing.history(start)['summarized'],
          decision == MealDecision.eatNowBolusLater
              ? reference
              : start.add(const Duration(minutes: 15)),
        );
      },
    );
  }

  test('future end identifies the event instead of blaming insulin', () {
    const timing = RetrospectiveMealTiming(eatingMinutes: 15);
    expect(
      () => timing.validate(
        DateTime(2026, 11, 2, 13, 36),
        DateTime(2026, 11, 2, 13, 38),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          lang.mealTimelineFutureEvent(lang.mealFlowEatingEnd, '13:51'),
        ),
      ),
    );
  });
}
