import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_status_history_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_progress/active_meal_wait_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets(
    'footer waits from recorded status time rather than advice or meal update',
    (tester) async {
      final now = DateTime(2026, 11, 1, 19);
      final meal = Meal(
        id: 1,
        name: 'Meal',
        status: 'bolused-waiting',
        updatedAt: now,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeNowProvider.overrideWithValue(AsyncData(now)),
            getMealAdviceProvider(meal).overrideWithValue(
              AsyncData(
                MealAdvice.full(
                  MealDecision.bolusWaitThenEat,
                  WaitSuggestion(15, 5, 20),
                  now.subtract(const Duration(minutes: 40)),
                ),
              ),
            ),
            mealStatusStartedAtProvider(
              const MealStatusStartedAtRequest(
                mealId: 1,
                status: 'bolused-waiting',
              ),
            ).overrideWith(
              (ref) async => now.subtract(const Duration(minutes: 5)),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ActiveMealWaitFooter(meal: meal)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10 min'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(2 / 3, 0.001),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
