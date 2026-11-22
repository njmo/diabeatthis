import 'package:diabeatthis/common/monitoring/meal_wait_status.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_progress/active_meal_wait_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('footer displays the monitor countdown and pending eCarbs', (
    tester,
  ) async {
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
          activeMealWaitClockProvider.overrideWith((ref) => Stream.value(now)),
          mealWaitStatusProvider.overrideWith(
            (ref) async => (
              mealId: 1,
              startedAt: now.subtract(const Duration(minutes: 5)),
              deadline: now.add(const Duration(minutes: 10)),
              waitingForExtendedCarbs: true,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: ActiveMealWaitFooter(meal: meal)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10:00'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(2 / 3, 0.001),
    );
    expect(tester.takeException(), isNull);
  });
}
