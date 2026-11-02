import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_category_edit_button.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final automatic in [true, false]) {
    testWidgets(
      'existing meal category edits preserve history and custom names (automatic: $automatic)',
      (tester) async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final name = automatic ? 'Posiłek: chleb żytni' : 'Moja własna nazwa';
        final id = await db
            .into(db.meal)
            .insert(MealCompanion.insert(name: name, plannedAt: 1000));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: localizedMaterialApp(
              home: Scaffold(body: MealCategoryEditButton(mealId: id)),
            ),
          ),
        );
        await tester.tap(find.text('Zmień rodzaj posiłku'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Obiad'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        final meal = (await db.mealDao.getMealById(id))!;
        expect(meal.category, 'lunch');
        expect(meal.name, automatic ? 'Obiad: chleb żytni' : name);
        expect(meal.plannedAt, 1000);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
