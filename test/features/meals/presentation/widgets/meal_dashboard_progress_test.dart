import 'package:diabeatthis/core/data/provider/parent_controller_provider.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list_today.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'active meal stays first, quick titles stay readable, and every date remains visible',
    (tester) async {
      final now = DateTime(2026, 11, 1, 19);
      final active = Meal(
        id: 9,
        name: 'QM: Tortilla',
        status: 'bolused-eating',
        plannedAt: DateTime(2026, 10, 31, 18),
      );
      final meals = [
        Meal(
          id: 1,
          name: 'Dzisiaj plan',
          status: 'planned',
          plannedAt: DateTime(2026, 11, 1, 21),
        ),
        Meal(
          id: 2,
          name: 'Jutro plan',
          status: 'planned',
          plannedAt: DateTime(2026, 11, 2, 8),
        ),
        Meal(
          id: 3,
          name: 'Dalszy plan',
          status: 'planned',
          plannedAt: DateTime(2026, 11, 4, 12),
        ),
        Meal(
          id: 4,
          name: 'Do sprawdzenia',
          status: 'eaten-extra',
          plannedAt: DateTime(2026, 11, 1, 15),
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeNowProvider.overrideWithValue(AsyncData(now)),
            anyMealBlockingActivationProvider.overrideWith(
              (ref) => Stream.value(active),
            ),
            plannedMealsForTodayStreamProvider.overrideWith(
              (ref) => Stream.value(meals),
            ),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(child: MealListToday()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tortilla'), findsOneWidget);
      expect(find.text('QM: Tortilla'), findsNothing);
      expect(find.text('Szybki posiłek'), findsOneWidget);
      expect(find.text('Zjadłem'), findsOneWidget);
      expect(find.text('Dokładka'), findsOneWidget);
      expect(find.text('Zjadłem teraz'), findsNothing);
      expect(find.text('Zjadłem wcześniej'), findsNothing);
      expect(find.byTooltip('Przerwij obsługę posiłku'), findsOneWidget);
      expect(find.text('Dzisiaj'), findsOneWidget);
      expect(find.text('Jutro'), findsOneWidget);
      expect(find.text('4.11.2026'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Tortilla')).dy,
        lessThan(tester.getTopLeft(find.text('Dzisiaj plan')).dy),
      );
      final summary = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Do sprawdzenia'),
          matching: find.byType(ListTile),
        ),
      );
      expect(summary.enabled, isTrue);
      final planned = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Jutro plan'),
          matching: find.byType(ListTile),
        ),
      );
      expect(planned.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'parent mode retains a separate delete action alongside interruption',
    (tester) async {
      final active = Meal(
        id: 1,
        name: 'Posiłek',
        status: 'bolused-eating',
        plannedAt: DateTime(2026, 11, 1),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parentModeProvider.overrideWithValue(true),
            timeNowProvider.overrideWithValue(AsyncData(DateTime(2026, 11, 1))),
            anyMealBlockingActivationProvider.overrideWith(
              (ref) => Stream.value(active),
            ),
            plannedMealsForTodayStreamProvider.overrideWith(
              (ref) => Stream.value([active]),
            ),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(body: MealListToday()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Usuń'), findsOneWidget);
      expect(find.byTooltip('Przerwij obsługę posiłku'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
