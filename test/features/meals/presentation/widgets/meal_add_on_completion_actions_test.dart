import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/common/widgets/amount_entry_dialog.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_completion_choice_sheet.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_ingredient_row.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list_today.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/tasks/meal_monitor_test.dart'
    show testBolusWizard;
import '../../../../helpers/delivered_meal_bolus.dart';
import '../../../../helpers/localized_material_app.dart';
import '../../../meal_summary/domain/use_cases/record_meal_add_on_use_case_test.dart'
    show addOnDraft, seedAddOnMeal;

void main() {
  test(
    'an older accepted calculator does not hide a new eCarbs-only instruction',
    () {
      final requestedAt = DateTime(2026, 11, 2, 12, 10, 0, 500);
      final progress = MealAddOnBolusContext(
        originalStatus: 'bolused-eating',
        eatingStartedAt: requestedAt,
        requestedAt: requestedAt,
        coveredCarbs: 42,
        statusCoveredCarbs: 42,
        reportedExtendedCarbs: 30,
        requestedCarbs: 0,
        requestedExtendedCarbs: 11,
        awaitingBolus: false,
        bolusConfirmed: true,
        acceptedWizardKeys: [
          'at:${requestedAt.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch}',
        ],
      );
      expect(progress.showCalculatorAction, isTrue);
      final acceptedThisSecond = progress.copyWith(
        acceptedWizardKeys: [
          'at:${requestedAt.millisecondsSinceEpoch ~/ 1000 * 1000}',
        ],
      );
      expect(acceptedThisSecond.showCalculatorAction, isFalse);
      expect(acceptedThisSecond.requestedExtendedCarbs, 11);
    },
  );

  testWidgets(
    'one add-on waits for its full bolus then finishes through the shared quantity editor',
    (tester) async {
      final start = DateTime(2026, 11, 2, 12);
      final requestedAt = start.add(const Duration(minutes: 10));
      final now = start.add(const Duration(minutes: 20));
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          timeNowProvider.overrideWithValue(AsyncData(now)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await withClock(Clock.fixed(now), () async {
        await seedAddOnMeal(db, start, status: 'bolused-eating');
        final declared = await addOnDraft(db, meat: 200, potatoes: 300);
        await withClock(
          Clock.fixed(requestedAt),
          () => container.read(recordMealAddOnUseCaseProvider).call(declared),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(
              home: const Scaffold(
                body: SingleChildScrollView(child: MealListToday()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final calculator = find.widgetWithText(
          OutlinedButton,
          'Otwórz kalkulator',
        );
        final finish = find.widgetWithText(FilledButton, 'Zjadłem');
        expect(find.widgetWithText(OutlinedButton, 'Dokładka'), findsNothing);
        expect(finish, findsOneWidget);
        expect(calculator, findsOneWidget);

        var progress = (await readMealAddOnBolusContext(db, 1))!;
        final originalECarbs = progress.requestedExtendedCarbs;
        expect(originalECarbs, greaterThan(0));
        progress = (await acceptDeliveredMealAddOnBolus(
          db,
          1,
          testBolusWizard(
            createdAt: requestedAt.add(const Duration(seconds: 1)),
            carbs: 20,
          ),
          requestedAt: requestedAt,
        ))!;
        await tester.pumpAndSettle();
        expect(progress.awaitingBolus, isTrue);
        expect(calculator, findsOneWidget);

        progress = (await acceptDeliveredMealAddOnBolus(
          db,
          1,
          testBolusWizard(
            createdAt: requestedAt.add(const Duration(seconds: 30)),
            carbs: progress.requestedCarbs.toDouble(),
          ),
          requestedAt: requestedAt,
        ))!;
        await tester.pumpAndSettle();
        expect(progress.awaitingBolus, isFalse);
        expect(progress.requestedExtendedCarbs, originalECarbs);
        expect(calculator, findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Dokładka'), findsNothing);
        expect((await db.mealDao.getMealById(1))!.status, 'eating-extra');

        await tester.tap(finish);
        await tester.pumpAndSettle();
        expect(find.byType(MealCompletionChoiceSheet), findsOneWidget);
        expect(find.text('Wszystko'), findsOneWidget);
        expect(find.text('Inaczej'), findsOneWidget);
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        expect(find.byType(MealCompletionView), findsOneWidget);
        final potatoes = find.byWidgetPredicate(
          (widget) =>
              widget is MealCompletionIngredientRow &&
              widget.mealIngredientId == 2,
        );
        final amount = find.descendant(
          of: potatoes,
          matching: find.text('300 g'),
        );
        await tester.scrollUntilVisible(
          amount,
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(amount);
        await tester.pumpAndSettle();
        await tester.tap(amount.hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(AmountEntryDialog), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), '250');
        await tester.tap(find.text('Zatwierdź'));
        await tester.pumpAndSettle();
        final actual = container
            .read(mealSummaryControllerProvider(1))
            .requireValue;
        expect(actual.itemsById[1]!.consumedAmount, 200);
        expect(actual.itemsById[2]!.consumedAmount, 250);
        expect(actual.itemsById[2]!.reportedAmount, 300);
        expect(
          (await db.mealIngredientsDao.getMealIngredientsForMeal(
            1,
          )).map((row) => row.consumedAmount),
          [200, 300],
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    },
  );
}
