import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'deferral defaults to one lesson and preserves a configured duration',
    () {
      expect(MealDecisionPreferences.decode(null).deferralMinutes, 45);
      final preferences = const MealDecisionPreferences().copyWith(
        deferralMinutes: 90,
      );
      expect(
        MealDecisionPreferences.decode(preferences.encode()).deferralMinutes,
        90,
      );
      for (final value in ['0', '-1', '181', '"45"']) {
        expect(
          MealDecisionPreferences.decode(
            '{"deferralMinutes":$value}',
          ).deferralMinutes,
          45,
        );
      }
    },
  );
}
