import '../../../../common/meal/manual_meal_decision.dart';
import '../../../../common/meal/meal_decision.dart';

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

  DateTime bolusAt(DateTime start) =>
      choice.decision == MealDecision.eatNowBolusLater
      ? start.add(Duration(minutes: bolusAfterStartMinutes))
      : start.subtract(Duration(minutes: choice.waitMinutes));

  void validate(DateTime start, DateTime now) {
    if (start.isAfter(now) ||
        bolusAt(start).isAfter(now) ||
        (eatingMinutes != null &&
            start.add(Duration(minutes: eatingMinutes!)).isAfter(now))) {
      throw ArgumentError(
        'Godziny posiłku i insuliny nie mogą być w przyszłości.',
      );
    }
    if (eatingMinutes == null || eatingMinutes! <= 0) {
      throw ArgumentError(
        'Podaj czas jedzenia, aby odtworzyć zakończenie posiłku.',
      );
    }
    if (choice.decision == MealDecision.bolus ||
        (choice.decision == MealDecision.bolusWaitThenEat &&
            choice.waitMinutes <= 0) ||
        (choice.decision != MealDecision.bolusWaitThenEat &&
            choice.waitMinutes != 0)) {
      throw ArgumentError('Nieprawidłowa decyzja lub czas czekania.');
    }
    if (choice.decision == MealDecision.eatNowBolusLater &&
        (bolusAfterStartMinutes <= 0 ||
            bolusAfterStartMinutes < (eatingMinutes ?? 0))) {
      throw ArgumentError(
        'Insulina po jedzeniu nie może poprzedzać końca posiłku.',
      );
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
