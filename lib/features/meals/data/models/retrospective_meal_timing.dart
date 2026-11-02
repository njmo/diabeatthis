import '../../../../common/l10n/language.dart';
import '../../../../common/meal/manual_meal_decision.dart';
import '../../../../common/meal/meal_decision.dart';
import '../../../../common/meal/meal_time_anchor.dart';

class RetrospectiveMealTiming {
  final ManualMealDecision choice;
  final int? eatingMinutes;
  final int bolusAfterStartMinutes;

  const RetrospectiveMealTiming({
    this.choice = const ManualMealDecision(),
    this.eatingMinutes,
    this.bolusAfterStartMinutes = 0,
  });

  RetrospectiveMealTiming copyWith({
    ManualMealDecision? choice,
    int? eatingMinutes,
    int? bolusAfterStartMinutes,
  }) => RetrospectiveMealTiming(
    choice: choice ?? this.choice,
    eatingMinutes: eatingMinutes ?? this.eatingMinutes,
    bolusAfterStartMinutes:
        bolusAfterStartMinutes ?? this.bolusAfterStartMinutes,
  );

  DateTime startFromReference(DateTime reference, MealTimeAnchor anchor) =>
      switch (anchor) {
        MealTimeAnchor.eatingStart => reference,
        MealTimeAnchor.eatingEnd => reference.subtract(
          Duration(minutes: eatingMinutes ?? 0),
        ),
        MealTimeAnchor.insulin =>
          choice.decision == MealDecision.eatNowBolusLater
              ? reference.subtract(Duration(minutes: bolusAfterStartMinutes))
              : reference.add(Duration(minutes: choice.waitMinutes)),
      };

  DateTime bolusAt(DateTime start) =>
      choice.decision == MealDecision.eatNowBolusLater
      ? start.add(Duration(minutes: bolusAfterStartMinutes))
      : start.subtract(Duration(minutes: choice.waitMinutes));

  void validate(DateTime start, DateTime now) {
    if (eatingMinutes == null || eatingMinutes! <= 0) {
      throw ArgumentError(lang.uiEnterTheEatingDurationToReconstructTheMealEnd);
    }
    if (choice.decision == MealDecision.bolus ||
        (choice.decision == MealDecision.bolusWaitThenEat &&
            choice.waitMinutes <= 0) ||
        (choice.decision != MealDecision.bolusWaitThenEat &&
            choice.waitMinutes != 0)) {
      throw ArgumentError(lang.uiInvalidDecisionOrWaitingTime);
    }
    if (choice.decision == MealDecision.eatNowBolusLater &&
        (bolusAfterStartMinutes <= 0 ||
            bolusAfterStartMinutes < (eatingMinutes ?? 0))) {
      throw ArgumentError(lang.uiInsulinAfterEatingCannotPrecedeTheEndOfThe);
    }
    final events = [
      (label: lang.uiEatingStarted, time: start),
      (label: lang.mealFlowInsulinTime, time: bolusAt(start)),
      (
        label: lang.mealFlowEatingEnd,
        time: start.add(Duration(minutes: eatingMinutes!)),
      ),
    ];
    for (final event in events) {
      if (event.time.isAfter(now)) {
        final time =
            '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';
        throw ArgumentError(lang.mealTimelineFutureEvent(event.label, time));
      }
    }
  }

  Map<String, DateTime> history(DateTime start) {
    final duration = eatingMinutes;
    if (duration == null || duration <= 0) {
      throw ArgumentError('Podaj czas jedzenia.');
    }
    final end = start.add(Duration(minutes: duration));
    final bolus = bolusAt(start);
    return switch (choice.decision) {
      MealDecision.eatNowBolusLater => {
        'eating-then-bolus': start,
        'waiting-for-bolus': end,
        'eaten-bolused': bolus,
        'summarized': bolus,
      },
      MealDecision.bolusAndEatNow => {
        'waiting-for-bolus': bolus,
        'bolused-eating': start,
        'eaten': end,
        'summarized': end,
      },
      MealDecision.bolusWaitThenEat => {
        'waiting-for-bolus': bolus,
        'bolused-waiting': bolus,
        'waited-eating': start,
        'eaten': end,
        'summarized': end,
      },
      MealDecision.bolus => throw ArgumentError('Unsupported meal decision'),
    };
  }
}
