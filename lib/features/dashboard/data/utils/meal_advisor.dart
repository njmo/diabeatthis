enum MealDecision {
  eatNowBolusLater,
  bolusAndEatNow,
  bolusWaitThenEat,
  eatSnackFirst,
}

class MealAdvice {
  final MealDecision decision;
  final WaitSuggestion? wait;

  MealAdvice(this.decision, this.wait);
}

class WaitSuggestion {
  final int recommendedMinutes;   // główny czas
  final int minMinutes;           // dolna granica okna
  final int maxMinutes;           // górna granica okna

  WaitSuggestion(this.recommendedMinutes, this.minMinutes, this.maxMinutes);
}

class MealAdvisor {
  MealAdvice getMealAdvice({
    required int bg,
    required double iob,
    required double cob,
    required int trend,
    required double mealCarbs,
    required double fatProteinExchanges,
  }) {
    final decision = decide(
      bg: bg,
      iob: iob,
      cob: cob,
      trend: trend,
      mealCarbs: mealCarbs,
      fatProteinExchanges: fatProteinExchanges,
    );

    if (decision == MealDecision.bolusWaitThenEat) {
      final wait = calculateWaitTime(
        bg: bg,
        trend: trend,
        iob: iob,
        mealCarbs: mealCarbs,
      );
      return MealAdvice(decision, wait);
    }

    return MealAdvice(decision, null);
  }

  MealDecision decide({
    required int bg,
    required double iob,
    required double cob,
    required int trend,
    required double mealCarbs,
    required double fatProteinExchanges,
  }) {
    int lowRisk = 0;

    if (bg < 90)
      lowRisk += 3;
    else if (bg < 110)
      lowRisk += 2;
    else if (bg < 140)
      lowRisk += 1;

    if (trend <= -20)
      lowRisk += 3;
    else if (trend <= -10)
      lowRisk += 2;
    else if (trend < 0)
      lowRisk += 1;

    if (iob > 2)
      lowRisk += 3;
    else if (iob > 1)
      lowRisk += 2;
    else if (iob > 0.5)
      lowRisk += 1;

    if (cob < 10) lowRisk += 1;

    int mealSpeed = 0;
    if (mealCarbs >= 30)
      mealSpeed += 2;
    else if (mealCarbs >= 15)
      mealSpeed += 1;
    if (fatProteinExchanges > 0) mealSpeed -= 1;

    if (lowRisk >= 6) {
      return MealDecision.eatNowBolusLater;
    }

    if (lowRisk >= 3) {
      if (trend <= -15) return MealDecision.eatNowBolusLater;
      if (mealSpeed >= 1) return MealDecision.bolusAndEatNow;
      return MealDecision.bolusWaitThenEat;
    }

    if (bg > 140 && trend >= 0) return MealDecision.bolusWaitThenEat;
    return MealDecision.bolusAndEatNow;
  }

  WaitSuggestion calculateWaitTime({
    required int bg,
    required int trend,
    required double iob,
    required double mealCarbs,
  }) {
    int minutes = 10; // start od środka

    // Cukier
    if (bg > 180) minutes += 3;
    else if (bg > 140) minutes += 2;
    else if (bg < 100) minutes -= 2;

    // Trend
    if (trend > 15) minutes += 3;
    else if (trend > 5) minutes += 2;
    else if (trend < -15) minutes -= 3;
    else if (trend < -5) minutes -= 2;

    // Aktywna insulina
    if (iob > 2) minutes -= 2;
    else if (iob > 1) minutes -= 1;

    // Wielkość posiłku
    if (mealCarbs > 60) minutes += 2;
    else if (mealCarbs < 20) minutes -= 1;

    // Ograniczenia 5–15 min
    minutes = minutes.clamp(5, 15);

    return WaitSuggestion(
      minutes,
      (minutes - 5).clamp(0, 15),
      (minutes + 5).clamp(5, 20),
    );
  }
}