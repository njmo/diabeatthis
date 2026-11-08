import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual decisions default to enabled for legacy preferences', () {
    expect(MealDecisionPreferences.decode('{}').allowManualDecision, isTrue);
    expect(MealDecisionPreferences.decode(null).allowManualDecision, isTrue);
  });

  test('manual decision preference survives copying and serialization', () {
    final preferences = const MealDecisionPreferences().copyWith(
      allowManualDecision: false,
    );
    expect(
      MealDecisionPreferences.decode(preferences.encode()).allowManualDecision,
      isFalse,
    );
  });

  test(
    'manual timeout fallback is normalized when manual decisions are disabled',
    () {
      final preferences = MealDecisionPreferences.decode(
        '{"allowManualDecision":false,"timeoutFallback":"manual"}',
      );
      expect(preferences.timeoutFallback, MealDecisionTimeoutFallback.app);
    },
  );
}
