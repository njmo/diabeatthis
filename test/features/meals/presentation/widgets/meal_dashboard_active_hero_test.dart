import 'package:diabeatthis/common/meal/meal_progress_plan.dart';
import 'package:diabeatthis/common/widgets/meal_progress/active_meal_progress_card.dart';
import 'package:diabeatthis/common/widgets/meal_progress/meal_interruption_dialog.dart';
import 'package:diabeatthis/core/data/provider/parent_controller_provider.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_progress_plan_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_status_history_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list_today.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  final now = DateTime(2026, 11, 1, 12);
  const summaryStatuses = ['eaten', 'eaten-extra', 'eaten-bolused'];
  const activeStatuses = [
    'waiting-for-bolus',
    'bolused-waiting',
    'eating',
    'eating-extra',
    'eating-then-bolus',
    'waited-eating',
    'bolused-eating',
  ];

  Future<void> showMeals(
    WidgetTester tester, {
    required List<Meal> meals,
    Meal? blockingMeal,
  }) async {
    final active = blockingMeal ?? firstMealBlockingActivation(meals);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parentModeProvider.overrideWithValue(false),
          timeNowProvider.overrideWithValue(AsyncData(now)),
          anyMealBlockingActivationProvider.overrideWith(
            (ref) => Stream.value(blockingMeal),
          ),
          plannedMealsForTodayStreamProvider.overrideWith(
            (ref) => Stream.value(meals),
          ),
          if (active != null) ...[
            mealProgressPlanProvider(active).overrideWithValue(
              AsyncData(mealProgressPlanForStatus(active.status)),
            ),
            getMealAdviceProvider(
              active,
            ).overrideWithValue(const AsyncData(null)),
            mealStatusStartedAtProvider(
              MealStatusStartedAtRequest(
                mealId: active.id,
                status: 'bolused-waiting',
              ),
            ).overrideWithValue(const AsyncData(null)),
          ],
        ],
        child: localizedMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(child: MealListToday()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ListTile mealTile(WidgetTester tester, String name) =>
      tester.widget<ListTile>(
        find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
      );

  testWidgets(
    'plans never become a hero and the nearest plan is the first ordinary row',
    (tester) async {
      await showMeals(
        tester,
        meals: [
          Meal(
            id: 3,
            name: 'Tomorrow',
            status: 'planned',
            plannedAt: DateTime(2026, 11, 2, 8),
          ),
          Meal(
            id: 2,
            name: 'Later today',
            status: 'planned',
            plannedAt: DateTime(2026, 11, 1, 20),
          ),
          Meal(
            id: 1,
            name: 'Nearest plan',
            status: 'planned',
            plannedAt: DateTime(2026, 11, 1, 13),
          ),
        ],
      );
      expect(find.byType(ActiveMealProgressCard), findsNothing);
      expect(find.text('Aktualny posiłek'), findsNothing);
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((tile) => (tile.title as Text).data),
        ['Nearest plan', 'Later today', 'Tomorrow'],
      );
      expect(mealTile(tester, 'Nearest plan').onTap, isNotNull);
    },
  );

  for (final status in summaryStatuses) {
    testWidgets(
      '$status remains accessible without a hero or current heading',
      (tester) async {
        await showMeals(
          tester,
          meals: [
            Meal(id: 1, name: 'Ready meal', status: status, plannedAt: now),
          ],
        );
        expect(find.byType(ActiveMealProgressCard), findsNothing);
        expect(find.text('Aktualny posiłek'), findsNothing);
        final tile = mealTile(tester, 'Ready meal');
        expect(tile.enabled, isTrue);
        expect(tile.onTap, isNotNull);
      },
    );
  }

  for (final status in activeStatuses) {
    testWidgets(
      'only $status is a hero while older summaries stay ordinary and accessible',
      (tester) async {
        final active = Meal(
          id: 9,
          name: 'Previous day active',
          status: status,
          plannedAt: now.subtract(const Duration(days: 1)),
        );
        await showMeals(
          tester,
          blockingMeal: active,
          meals: [
            for (var index = 0; index < summaryStatuses.length; index++)
              Meal(
                id: index + 1,
                name: 'Summary $index',
                status: summaryStatuses[index],
                plannedAt: now.subtract(const Duration(days: 2)),
              ),
            Meal(
              id: 10,
              name: 'Next plan',
              status: 'planned',
              plannedAt: now.add(const Duration(hours: 1)),
            ),
          ],
        );
        expect(find.byType(ActiveMealProgressCard), findsOneWidget);
        expect(find.text('Aktualny posiłek'), findsOneWidget);
        expect(
          tester
              .widget<ActiveMealProgressCard>(
                find.byType(ActiveMealProgressCard),
              )
              .name,
          'Previous day active',
        );
        expect(
          tester.getTopLeft(find.text('Previous day active')).dy,
          lessThan(tester.getTopLeft(find.text('Summary 0')).dy),
        );
        for (var index = 0; index < summaryStatuses.length; index++) {
          final summary = mealTile(tester, 'Summary $index');
          expect(summary.enabled, isTrue);
          expect(summary.onTap, isNotNull);
        }
        expect(mealTile(tester, 'Next plan').enabled, isFalse);
      },
    );
  }

  for (final canFinishEating in [false, true]) {
    testWidgets(
      'interruption instructions match the available finish action: $canFinishEating',
      (tester) async {
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: MealInterruptionDialog(canFinishEating: canFinishEating),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Przerwij'), findsOneWidget);
        expect(find.text('Anuluj'), findsOneWidget);
        expect(
          find.text('Skończyłem jeść'),
          canFinishEating ? findsOneWidget : findsNothing,
        );
        const preservation =
            'Posiłek zniknie z aktywnych. Historia i zapis bolusa pozostaną zachowane.';
        expect(
          find.text(
            canFinishEating
                ? '$preservation Jeśli skończyłeś jeść, także tylko część porcji, wybierz podsumowanie.'
                : preservation,
          ),
          findsOneWidget,
        );
      },
    );
  }
}
