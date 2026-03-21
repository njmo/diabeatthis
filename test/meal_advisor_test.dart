// File: test/meal_advisor_param_test.dart
//
// Parametryczny test (Flutter) dla MealAdvisor (TTL vs TAF z makro: carbs/fat/protein/fiber).
// Zestaw przypadków jest "życiowy" i spójny: COB i IOB nie kłócą się ze sobą.
//
// Uruchamianie:
//   flutter test -r expanded
//
// WAŻNE: MealAdvisor oczekuje `trend` w mg/dL NA MINUTĘ.
// Jeśli masz trend w mg/dL na 5 minut, przelicz przed wywołaniem:
//   trendPerMin = (trendPer5Min / 5).round()

import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:flutter_test/flutter_test.dart';


class MealTestCase {
  final String name;

  // State
  final int bg;
  final double iob;
  final double cob;
  final int trendPerMin;

  // Meal macros
  final double carbsG;
  final double fatG;
  final double proteinG;
  final double fiberG;

  // Expected
  final MealDecision expectedDecision;
  final int? expectedWaitRecommended;
  final int? expectedWaitMin;
  final int? expectedWaitMax;

  const MealTestCase({
    required this.name,
    required this.bg,
    required this.iob,
    required this.cob,
    required this.trendPerMin,
    required this.carbsG,
    required this.fatG,
    required this.proteinG,
    required this.fiberG,
    required this.expectedDecision,
    this.expectedWaitRecommended,
    this.expectedWaitMin,
    this.expectedWaitMax,
  });
}

void main() {
  group('MealAdvisor TTL vs TAF (real-life-ish) parameterized', () {
    final advisor = MealAdvisor(
      config: const MealAdvisorConfig(
        // Używamy domyślnych parametrów z implementacji, by oczekiwania były deterministyczne.
      ),
    );

    final cases = <MealTestCase>[
      // 1) Hipoglikemia blisko + duże IOB (korekty/stackowanie) -> jedz teraz, bez bolusa teraz
      MealTestCase(
        name: 'Fast drop + high IOB (stacking) -> eatNowBolusLater',
        bg: 95,
        iob: 2.0,
        cob: 0, // korekty bez jedzenia -> COB ~ 0
        trendPerMin: -3,
        carbsG: 15, // sok/żel
        fatG: 0,
        proteinG: 0,
        fiberG: 0,
        expectedDecision: MealDecision.eatNowBolusLater,
      ),

      // 2) Wciąż trawi się poprzedni posiłek: COB wysokie i IOB też obecne (spójne)
      //    Stabilny BG, brak spadku -> bolus i jedz (normalnie)
      MealTestCase(
        name: 'Still digesting previous meal (COB high, IOB present) -> bolusAndEatNow',
        bg: 120,
        iob: 1.4,
        cob: 25,
        trendPerMin: 0,
        carbsG: 40,
        fatG: 10,
        proteinG: 15,
        fiberG: 6,
        expectedDecision: MealDecision.bolusAndEatNow,
      ),

      // 3) Owsianka (błonnik) + umiarkowane IOB + lekki spadek -> ostrożnie
      MealTestCase(
        name: 'Oatmeal (fiber) + moderate IOB + mild drop -> eatNowBolusLater',
        bg: 110,
        iob: 1.2,
        cob: 5, // małe COB może być (końcówka wcześniejszego wchłaniania)
        trendPerMin: -1,
        carbsG: 40,
        fatG: 6,
        proteinG: 10,
        fiberG: 8,
        expectedDecision: MealDecision.eatNowBolusLater,
      ),

      // 4) Pizza: wysoki tłuszcz/białko, świeże IOB (po posiłku/korektach), trend lekko w dół
      //    -> TAF duży, TTL skrócone przez IOB -> ostrożnie
      MealTestCase(
        name: 'Pizza (mixed high fat) + high IOB -> eatNowBolusLater',
        bg: 125,
        iob: 2.2,
        cob: 0, // zakładamy, że to decyzja "przed jedzeniem", więc COB=0
        trendPerMin: -1,
        carbsG: 60,
        fatG: 20,
        proteinG: 25,
        fiberG: 4,
        expectedDecision: MealDecision.eatNowBolusLater,
      ),

      // 5) Normalny lunch (kanapka): przed posiłkiem COB niskie i IOB małe
      //    -> klasycznie bolus i jedz
      MealTestCase(
        name: 'Normal lunch sandwich, stable, low IOB, low COB -> bolusAndEatNow',
        bg: 115,
        iob: 0.3,
        cob: 0,
        trendPerMin: 0,
        carbsG: 45,
        fatG: 8,
        proteinG: 18,
        fiberG: 5,
        expectedDecision: MealDecision.bolusAndEatNow,
      ),

      // 6) Near-zone: lekki spadek, małe IOB, szybkie węgle (niski TAF),
      //    BG nie jest niskie -> bolus i jedz
      MealTestCase(
        name: 'Near zone: mild drop, small IOB, fast carbs -> bolusAndEatNow',
        bg: 120,
        iob: 0.2,
        cob: 0,
        trendPerMin: -2,
        carbsG: 30,
        fatG: 0,
        proteinG: 0,
        fiberG: 0,
        expectedDecision: MealDecision.bolusAndEatNow,
      ),

      // 7) Wysoki BG i rośnie + posiłek mieszany -> bolus, poczekaj, potem jedz
      //    Oczekujemy clampa wait do 15.
      MealTestCase(
        name: 'High BG rising + mixed meal -> bolusWaitThenEat (max wait)',
        bg: 190,
        iob: 0.5,
        cob: 0,
        trendPerMin: 1,
        carbsG: 60,
        fatG: 15,
        proteinG: 25,
        fiberG: 5,
        expectedDecision: MealDecision.bolusWaitThenEat,
        expectedWaitRecommended: 15,
        expectedWaitMin: 10,
        expectedWaitMax: 20,
      ),

      // 8) Wysoki BG, trend 0, ale IOB już spore (po korektach) -> nadal waitThenEat,
      //    a wait wychodzi umiarkowanie (ok. 13) w tej konfiguracji.
      MealTestCase(
        name: 'High BG flat + IOB from corrections -> bolusWaitThenEat (moderate wait)',
        bg: 160,
        iob: 1.7,
        cob: 0, // korekty bez jedzenia -> COB ~ 0
        trendPerMin: 0,
        carbsG: 60,
        fatG: 3,
        proteinG: 5,
        fiberG: 2,
        expectedDecision: MealDecision.bolusWaitThenEat,
        expectedWaitRecommended: 13,
        expectedWaitMin: 8,
        expectedWaitMax: 18,
      ),

      // 9) Granicznie nisko i spada: nawet szybkie węgle -> jedz teraz bez bolusa
      MealTestCase(
        name: 'Borderline low soon + dropping -> eatNowBolusLater',
        bg: 90,
        iob: 0.8,
        cob: 0,
        trendPerMin: -2,
        carbsG: 30,
        fatG: 0,
        proteinG: 0,
        fiberG: 0,
        expectedDecision: MealDecision.eatNowBolusLater,
      ),

      // 10) Sałatka "tłusta" (mało węgli, dużo tłuszczu) + BG wysokie i stabilnie:
      //     posiłek wolny, BG wysokie, trend nie spada -> waitThenEat, wait clamp do 15.
      MealTestCase(
        name: 'Fatty low-carb salad + high BG stable -> bolusWaitThenEat (max wait)',
        bg: 150,
        iob: 0.5,
        cob: 0,
        trendPerMin: 0,
        carbsG: 8,
        fatG: 20,
        proteinG: 15,
        fiberG: 5,
        expectedDecision: MealDecision.bolusWaitThenEat,
        expectedWaitRecommended: 15,
        expectedWaitMin: 10,
        expectedWaitMax: 20,
      ),

      // 11) "Słodka przekąska" z tłuszczem (np. baton) – węgle są, ale tłuszcz podbija TAF.
      //     BG średnie, IOB umiarkowane, trend lekko spada -> ostrożnie.
      MealTestCase(
        name: 'Candy bar (carbs+fat) + moderate IOB + slight drop -> eatNowBolusLater',
        bg: 115,
        iob: 1.0,
        cob: 0,
        trendPerMin: -1,
        carbsG: 30,
        fatG: 12,
        proteinG: 4,
        fiberG: 2,
        expectedDecision: MealDecision.eatNowBolusLater,
      ),

      // 12) "Ryż + kurczak" (umiarkowanie mieszane), BG normalne, małe IOB, trend lekko w górę:
      //     klasycznie bolus i jedz (bez czekania, bo BG nie jest wysokie).
      MealTestCase(
        name: 'Rice+chicken, slight rise, low IOB -> bolusAndEatNow',
        bg: 125,
        iob: 0.4,
        cob: 0,
        trendPerMin: 1,
        carbsG: 55,
        fatG: 6,
        proteinG: 25,
        fiberG: 3,
        expectedDecision: MealDecision.bolusAndEatNow,
      ),
    ];

    for (final tc in cases) {
      test(
        tc.name,
            () {
          final advice = advisor.getMealAdvice(
            bg: tc.bg,
            iob: tc.iob,
            cob: tc.cob,
            trend: tc.trendPerMin,
            mealCarbs: tc.carbsG,
            fatGrams: tc.fatG,
            proteinGrams: tc.proteinG,
            fiberGrams: tc.fiberG,
          );

          expect(
            advice.decision,
            tc.expectedDecision,
            reason:
            'Decision mismatch for "${tc.name}" (bg=${tc.bg}, iob=${tc.iob}, cob=${tc.cob}, trend=${tc.trendPerMin})',
          );

          if (tc.expectedDecision != MealDecision.bolusWaitThenEat) {
            expect(advice.wait, isNull, reason: 'Wait should be null for "${tc.name}"');
            return;
          }

          expect(advice.wait, isNotNull, reason: 'Wait should not be null for "${tc.name}"');

          expect(advice.wait!.recommendedMinutes, tc.expectedWaitRecommended,
              reason: 'Recommended wait mismatch for "${tc.name}"');
          expect(advice.wait!.minMinutes, tc.expectedWaitMin,
              reason: 'Min wait mismatch for "${tc.name}"');
          expect(advice.wait!.maxMinutes, tc.expectedWaitMax,
              reason: 'Max wait mismatch for "${tc.name}"');
        },
      );
    }
  });
}
