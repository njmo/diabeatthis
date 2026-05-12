import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/trailing_wait_after_bolus_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('does not fail while current time is still loading', (
    tester,
  ) async {
    final meal = Meal(id: 1, name: 'Test');
    final now = DateTime(2026, 5, 12, 12);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timeNowProvider.overrideWithValue(const AsyncLoading()),
          getMealAdviceProvider(meal).overrideWithValue(
            AsyncData(
              MealAdvice.full(
                MealDecision.bolusWaitThenEat,
                WaitSuggestion(15, 5, 20),
                now,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: TrailingWaitAfterBolusStatus(meal: meal)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('min'), findsNothing);
  });

  testWidgets('renders remaining wait minutes when advice and time are ready', (
    tester,
  ) async {
    final meal = Meal(id: 1, name: 'Test');
    final now = DateTime(2026, 5, 12, 12);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timeNowProvider.overrideWithValue(AsyncData(now)),
          getMealAdviceProvider(meal).overrideWithValue(
            AsyncData(
              MealAdvice.full(
                MealDecision.bolusWaitThenEat,
                WaitSuggestion(15, 5, 20),
                now.subtract(const Duration(minutes: 5)),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: TrailingWaitAfterBolusStatus(meal: meal)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('10min'), findsOneWidget);
  });
}
