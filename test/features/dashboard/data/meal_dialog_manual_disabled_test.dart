import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_dialog_history_fallback_test.dart';

void main() {
  test('disabled manual decisions cannot prepare or save a choice', () async {
    await withMealHistoryFixture((fixture) async {
      await fixture.container.read(saveMealDecisionPreferencesProvider)(
        const MealDecisionPreferences(allowManualDecision: false),
      );
      await fixture.controller.chooseEat(manual: const ManualMealDecision());
      expect(fixture.state.advice.decision, isNull);
      expect(fixture.state.preparationFailed, isTrue);
      expect(
        await fixture.db.select(fixture.db.mealAdvisorResult).get(),
        isEmpty,
      );
      expect((await fixture.db.mealDao.getMealById(1))!.status, 'planned');
    });
  });

  test(
    'disabling manual decisions after preparation prevents saving',
    () async {
      await withMealHistoryFixture((fixture) async {
        await fixture.controller.chooseEat(manual: const ManualMealDecision());
        expect(fixture.state.advice.source, 'manual');
        await fixture.container.read(saveMealDecisionPreferencesProvider)(
          const MealDecisionPreferences(allowManualDecision: false),
        );
        expect(await fixture.controller.confirmAdvice(), isFalse);
        expect(
          await fixture.db.select(fixture.db.mealAdvisorResult).get(),
          isEmpty,
        );
        expect((await fixture.db.mealDao.getMealById(1))!.status, 'planned');
      });
    },
  );
}
