import 'package:diabeatthis/common/widgets/history_day_section.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list/meal_list_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('day sections start open and toggle independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              HistoryDaySection(
                date: DateTime(2026, 11, 2),
                itemCount: 1,
                itemBuilder: (_, _) => const Text('First day'),
              ),
              HistoryDaySection(
                date: DateTime(2026, 11, 1),
                itemCount: 1,
                itemBuilder: (_, _) => const Text('Second day'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('First day').hitTestable(), findsOneWidget);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(find.text('First day').hitTestable(), findsNothing);
    expect(find.text('Second day').hitTestable(), findsOneWidget);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(find.text('First day').hitTestable(), findsOneWidget);
  });

  testWidgets('grouped meals retain open and confirmed-delete callbacks', (
    tester,
  ) async {
    final meal = Meal(
      id: 1,
      name: 'Dinner',
      plannedAt: DateTime(2026, 11, 2, 20),
    );
    Meal? opened;
    Meal? deleteRequested;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: MealListContent(
            meals: [meal],
            isInitialLoading: false,
            isLoadingMore: false,
            hasMore: false,
            hasError: false,
            onLoadMore: () {},
            onRetry: () {},
            onMealTap: (value) => opened = value,
            onMealDelete: (value) async {
              deleteRequested = value;
              return false;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dinner'));
    expect(opened, meal);
    await tester.drag(find.byType(Dismissible), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(deleteRequested, meal);
    expect(find.text('Dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
