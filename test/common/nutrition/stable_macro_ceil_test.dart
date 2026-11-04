import 'package:diabeatthis/common/nutrition/stable_macro_ceil.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'machine noise around nonzero integer boundaries does not add or remove a gram',
    () {
      expect(stableMacroCeil(30.000000000000004), 30);
      expect(stableMacroCeil(29.999999999999996), 30);
      expect(stableMacroCeil(-29.999999999999996), -30);
      expect(stableMacroCeil(-30.000000000000004), -30);
      expect(stableMacroCeil(0), 0);
    },
  );
  test(
    'genuine fractional nutrition and tiny positive quantities retain ceiling semantics',
    () {
      expect(stableMacroCeil(1e-15), 1);
      expect(stableMacroValue(1e-15), 1e-15);
      expect(stableMacroCeil(30.000001), 31);
      expect(stableMacroCeil(-29.999999), -29);
      expect(stableMacroCeil(.4 + .4), 1);
      expect(stableMacroCeil(7.5 + 3.5 + 2.5), 14);
    },
  );
  test(
    'coverage subtraction stabilizes operands without deleting genuine nearzero values',
    () {
      expect(
        stableMacroCeil(
          stableMacroValue(30.000000000000004) - stableMacroValue(30),
        ),
        0,
      );
      expect(
        stableMacroCeil(stableMacroValue(30.000001) - stableMacroValue(30)),
        1,
      );
      expect(stableMacroCeil(stableMacroValue(1e-15) - stableMacroValue(0)), 1);
    },
  );
  test(
    'fractional coverage cancellation uses operand scale and preserves a genuine tiny quantity',
    () {
      expect(stableMacroDifference(.8000000000000002, .8), 0);
      expect(stableMacroDifference(.8, .8000000000000002), 0);
      expect(stableMacroDifference(1e-15, 0), 1e-15);
      expect(stableMacroCeil(stableMacroDifference(1e-15, 0)), 1);
      expect(stableMacroCeil(stableMacroDifference(.800001, .8)), 1);
    },
  );
  test(
    'WBT threshold and gram conversion remain stable while genuine surplus stays actionable',
    () {
      const calculator = WbtExtendedCarbsCalculator();
      expect(calculator.calculateFromKcal(100.00000000000001).grams, 0);
      expect(calculator.calculateFromKcal(100.000001).grams, 11);
      expect(calculator.calculateFromKcal(300.00000000000006).grams, 30);
      expect(calculator.calculateFromKcal(300.000001).grams, 31);
    },
  );
}
