import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/common/widgets/meal_category_field.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_planned_time_field.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_timing_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  testWidgets(
    'review generates the name, requires a category and updates its prefix',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(home: const AddMealPage()),
        ),
      );
      await tester.pumpAndSettle();
      container.read(mealDraftProvider.notifier).setMealIngredients([
        mealFlowIngredient(container),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dalej: kiedy'));
      await tester.pumpAndSettle();
      final date = DateTime.now().add(const Duration(hours: 1));
      tester
          .widget<MealTimingStep>(find.byType(MealTimingStep))
          .onDateChanged(date);
      tester
          .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
          .didChange(date);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dalej: podsumowanie'));
      await tester.pumpAndSettle();
      expect(find.text('Posiłek: Oatmeal'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Zaplanuj posiłek'));
      await tester.pumpAndSettle();
      expect(find.text('Wybierz rodzaj posiłku.'), findsOneWidget);
      tester
          .widget<MealCategoryField>(find.byType(MealCategoryField))
          .onChanged(MealCategory.lunch);
      await tester.pumpAndSettle();
      expect(find.text('Obiad: Oatmeal'), findsOneWidget);
      expect(container.read(mealDraftProvider).name, 'Obiad: Oatmeal');
      tester
          .widget<MealCategoryField>(find.byType(MealCategoryField))
          .onChanged(MealCategory.dinner);
      await tester.pumpAndSettle();
      expect(container.read(mealDraftProvider).name, 'Kolacja: Oatmeal');
      expect(tester.takeException(), isNull);
    },
  );
}
