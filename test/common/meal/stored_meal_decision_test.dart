import 'package:diabeatthis/common/meal/stored_meal_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persisted statuses and enum names use the same Polish label', () {
    for (final pair in [
      ['bolused-waiting', 'bolusWaitThenEat'],
      ['bolused-eating', 'bolusAndEatNow'],
      ['eating-then-bolus', 'eatNowBolusLater'],
    ]) {
      expect(storedMealDecision(pair.first), isNotNull);
      expect(
        storedMealDecisionLabel(pair.first),
        storedMealDecisionLabel(pair.last),
      );
    }
    expect(
      storedMealDecisionLabel('bolused-waiting'),
      'Insulina, czekanie, jedzenie',
    );
    expect(storedMealDecisionLabel('manual'), 'Decyzja ręczna');
    expect(storedMealDecision('unsupported'), isNull);
    expect(storedMealDecisionLabel(null), 'Nieznany wynik');
  });
}
