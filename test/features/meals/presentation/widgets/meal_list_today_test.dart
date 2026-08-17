import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list_today.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('blocks opening another meal while one meal is active', (
    tester,
  ) async {
    final plannedAt = DateTime.now().add(const Duration(hours: 1));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anyMealBlockingActivationProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          plannedMealsForTodayStreamProvider.overrideWith(
            (ref) => Stream.value([
              Meal(
                id: 1,
                name: 'Aktywny',
                plannedAt: plannedAt,
                status: 'waiting-for-bolus',
              ),
              Meal(
                id: 2,
                name: 'Drugi',
                plannedAt: plannedAt.add(const Duration(minutes: 30)),
                status: 'planned',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MealListToday())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aktywny'), findsOneWidget);
    expect(find.text('Drugi'), findsOneWidget);

    await tester.tap(find.text('Drugi'));
    await tester.pumpAndSettle();

    expect(find.text('Zjem'), findsNothing);
  });

  testWidgets('blocks opening meal when active meal is outside today list', (
    tester,
  ) async {
    final plannedAt = DateTime.now().add(const Duration(hours: 1));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anyMealBlockingActivationProvider.overrideWith(
            (ref) => Stream.value(
              Meal(
                id: 99,
                name: 'Wczorajszy aktywny',
                plannedAt: plannedAt.subtract(const Duration(days: 1)),
                status: 'waiting-for-bolus',
              ),
            ),
          ),
          plannedMealsForTodayStreamProvider.overrideWith(
            (ref) => Stream.value([
              Meal(
                id: 2,
                name: 'Drugi',
                plannedAt: plannedAt.add(const Duration(minutes: 30)),
                status: 'planned',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MealListToday())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drugi'));
    await tester.pumpAndSettle();

    expect(find.text('Zjem'), findsNothing);
  });

  testWidgets(
    'keeps ready to summarize meal open while another meal is active',
    (tester) async {
      final plannedAt = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            anyMealBlockingActivationProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            plannedMealsForTodayStreamProvider.overrideWith(
              (ref) => Stream.value([
                Meal(
                  id: 1,
                  name: 'Aktywny',
                  plannedAt: plannedAt,
                  status: 'waiting-for-bolus',
                ),
                Meal(
                  id: 2,
                  name: 'Do podsumowania',
                  plannedAt: plannedAt.add(const Duration(minutes: 30)),
                  status: 'eaten',
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: MealListToday())),
        ),
      );
      await tester.pumpAndSettle();

      final tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Do podsumowania'),
          matching: find.byType(ListTile),
        ),
      );

      expect(tile.enabled, isTrue);
    },
  );
}
