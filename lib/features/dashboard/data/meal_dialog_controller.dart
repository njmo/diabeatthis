import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/drift/dao/ingredient_dao.dart';
import '../../meals/data/providers/meal_ingredients_list_provider.dart';
import 'meal_dialog_state.dart';
import 'providers/device_status_provider.dart';

part 'meal_dialog_controller.g.dart';

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

String waitTimeMessage(WaitSuggestion w) {
  return "Odczekaj około ${w.recommendedMinutes} min "
      "(zakres ${w.minMinutes}–${w.maxMinutes} min) przed rozpoczęciem posiłku.";
}

@riverpod
class MealDialogController extends _$MealDialogController {
  late final int meal_id;

  @override
  MealDialogState build(int mealId) {
    meal_id = mealId;
    final s = MealDialogState.initial();
    return s.copyWith(waitHint: "Ładowanie…");
  }

  int parseTick(String? tickRaw) {
    if (tickRaw == null) return 0;
    final cleaned = tickRaw.trim().replaceAll(',', '.');
    return int.tryParse(cleaned) ??
        int.tryParse(cleaned.replaceAll('+', '')) ??
        0;
  }
  Future<String?> _computeWaitHint(double  carbs, double fatProteinExchanges) async {
    final deviceStatusStream = await ref.read(
      deviceStatusStreamProvider.future,
    );

    final advice = getMealAdvice(bg: deviceStatusStream.bg, iob: deviceStatusStream.iob, cob: deviceStatusStream.cob, trend: parseTick(deviceStatusStream.tick), mealCarbs: carbs, fatProteinExchanges: fatProteinExchanges);
    return mealAdviceLabel(advice);
  }

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
    print(decision);

    if (decision == MealDecision.bolusWaitThenEat) {
      final wait = calculateWaitTime(
        bg: bg,
        trend: trend,
        iob: iob,
        mealCarbs: mealCarbs,
      );
      print(wait.recommendedMinutes);
      return MealAdvice(decision, wait);
    }

    return MealAdvice(decision, null);
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

  Future<void> chooseEat() async {
    final mealStatus = await ref.read(
      mealMacronutrientsSummaryProvider(meal_id).future,
    );

    state = state.copyWith(
      skipMeal: false,
      step: MealDialogStep.details,
      carbsGrams: mealStatus?.carbsG,
      extendedCarbsGrams: (mealStatus!.fatKcal + mealStatus.proteinKcal) / 10.0,
      waitHint: await _computeWaitHint(state.carbsGrams, state.extendedCarbsGrams),
    );
  }

  String? mealAdviceLabel(MealAdvice advice) {
    switch (advice.decision) {
      case MealDecision.eatNowBolusLater:
        return "Jedz teraz, insulinę podaj później";
      case MealDecision.bolusAndEatNow:
        return "Podaj insulinę i jedz";
      case MealDecision.bolusWaitThenEat:
        return "Podaj insulinę, odczekaj ${waitTimeMessage(advice.wait!)}i jedz";
      case MealDecision.eatSnackFirst:
        return "Najpierw mała przekąska";
    }
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

  void chooseSkip() {
    state = state.copyWith(skipMeal: true, step: MealDialogStep.confirm);
  }

  void back() {
    if (state.step == MealDialogStep.details) {
      state = state.copyWith(step: MealDialogStep.choose);
    } else if (state.step == MealDialogStep.confirm) {
      state = state.copyWith(
        step: state.skipMeal ? MealDialogStep.choose : MealDialogStep.details,
      );
    }
  }

  void next() {
    if (state.step == MealDialogStep.details) {
      state = state.copyWith(step: MealDialogStep.confirm);
    }
  }

  Future<void> save() async {}
}
