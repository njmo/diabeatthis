import 'package:auto_route/auto_route.dart';
import 'package:diabeatthis/app/router/app_router.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_time_anchor.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_picker_field.dart';
import 'package:diabeatthis/common/widgets/meal_time_anchor_field.dart';
import 'package:diabeatthis/common/widgets/meal_timeline_preview.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/models/retrospective_meal_timing.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_composition_step.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_planned_time_field.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_review_name.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_review_step.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_timing_step.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_preview_tile.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  testWidgets(
    'empty composition cannot advance and date validates only on next',
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
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Dalej: kiedy'),
            )
            .onPressed,
        isNull,
      );
      container.read(mealDraftProvider.notifier).setMealIngredients([
        mealFlowIngredient(container),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dalej: kiedy'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
            .hasError,
        isFalse,
      );
      await tester.tap(find.text('Dalej: podsumowanie'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
            .hasError,
        isTrue,
      );
      expect(find.byType(MealReviewStep), findsNothing);
    },
  );

  testWidgets('copied source survives steps and retains the original lineage', (
    tester,
  ) async {
    final source = CopiedMealFromMeal(
      id: 11,
      name: 'Source breakfast',
      date: DateTime(2025),
      copiedFromMealId: 5,
      copiedFromTemplateId: 7,
    );
    late ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        getMealIngredientsDraftForMealProvider(
          11,
        ).overrideWith((_) async => [mealFlowIngredient(container)]),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(home: const AddMealPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      await tester
          .widget<MealCompositionStep>(find.byType(MealCompositionStep))
          .onPicked(source),
      isTrue,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalej: kiedy'));
    await tester.pumpAndSettle();
    final selected = DateTime.now().add(const Duration(hours: 1));
    tester
        .widget<MealTimingStep>(find.byType(MealTimingStep))
        .onDateChanged(selected);
    tester
        .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
        .didChange(selected);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalej: podsumowanie'));
    await tester.pumpAndSettle();
    expect(find.text('Skopiowano z: Source breakfast'), findsOneWidget);
    tester
        .widget<MealReviewStep>(find.byType(MealReviewStep))
        .onChangeComposition();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MealCompositionStep>(find.byType(MealCompositionStep))
          .source,
      source,
    );
    expect(container.read(mealDraftProvider).basedOnMealId, 5);
    expect(container.read(mealDraftProvider).mealTemplateId, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rejects insulin before eating ends without leaving the timing step',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: AddMealPage(
              retrospective: true,
              initialEatenAt: DateTime(2025),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container.read(mealDraftProvider.notifier).setMealIngredients([
        mealFlowIngredient(container),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dalej: kiedy'));
      await tester.pumpAndSettle();
      tester
          .widget<MealTimingStep>(find.byType(MealTimingStep))
          .onTimingChanged(
            const RetrospectiveMealTiming(
              choice: ManualMealDecision(
                decision: MealDecision.eatNowBolusLater,
              ),
              eatingMinutes: 20,
              bolusAfterStartMinutes: 10,
            ),
          );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jak długo trwało jedzenie? (min)'),
        '20',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dalej: podsumowanie'));
      await tester.pumpAndSettle();
      expect(find.byType(MealTimingStep), findsOneWidget);
      expect(
        find.text(lang.uiInsulinAfterEatingCannotPrecedeTheEndOfThe),
        findsOneWidget,
      );
      expect(find.byType(MealReviewStep), findsNothing);
    },
  );

  testWidgets('end reference recalculates offsets and survives step navigation', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reference = DateTime(2025, 11, 2, 13, 36);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: AddMealPage(retrospective: true, initialEatenAt: reference),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(mealDraftProvider.notifier).setMealIngredients([
      mealFlowIngredient(container),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalej: kiedy'));
    await tester.pumpAndSettle();
    tester
        .widget<MealTimingStep>(find.byType(MealTimingStep))
        .onTimingChanged(
          const RetrospectiveMealTiming(
            choice: ManualMealDecision(
              decision: MealDecision.bolusWaitThenEat,
              waitMinutes: 5,
            ),
            eatingMinutes: 15,
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MealTimeAnchorField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koniec jedzenia').last);
    await tester.pumpAndSettle();
    var preview = tester.widget<MealTimelinePreview>(
      find.byType(MealTimelinePreview),
    );
    expect(preview.startedAt, DateTime(2025, 11, 2, 13, 21));
    expect(preview.insulinAt, DateTime(2025, 11, 2, 13, 16));
    expect(preview.endedAt, reference);
    expect(container.read(mealDraftProvider).plannedAt, preview.startedAt);
    // Changing the duration recalculates both earlier events, keeping the end fixed.
    final duration = find.widgetWithText(
      TextFormField,
      'Jak długo trwało jedzenie? (min)',
    );
    await tester.ensureVisible(duration);
    await tester.enterText(duration, '20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    preview = tester.widget<MealTimelinePreview>(
      find.byType(MealTimelinePreview),
    );
    expect(preview.startedAt, DateTime(2025, 11, 2, 13, 16));
    expect(preview.insulinAt, DateTime(2025, 11, 2, 13, 11));
    expect(preview.endedAt, reference);
    await tester.tap(find.text('Wstecz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalej: kiedy'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MealTimeAnchorField>(find.byType(MealTimeAnchorField))
          .value,
      MealTimeAnchor.eatingEnd,
    );
    expect(
      tester
          .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
          .value,
      reference,
    );
    await tester.tap(find.text('Dalej: podsumowanie'));
    await tester.pumpAndSettle();
    expect(find.byType(MealReviewStep), findsOneWidget);
    expect(
      container.read(mealDraftProvider).plannedAt,
      DateTime(2025, 11, 2, 13, 16),
    );
    expect(tester.takeException(), isNull);
  });

  for (final decision in <MealDecision?>[
    null,
    MealDecision.bolusAndEatNow,
    MealDecision.bolusWaitThenEat,
    MealDecision.eatNowBolusLater,
  ]) {
    testWidgets('reviews and saves complete flow: $decision', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'TestHome',
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          AutoRoute(page: AddMealRoute.page),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router.config(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final retrospective = decision != null;
      final calculatorDate = DateTime(2025, 9, 10, 12);
      final result = router.push<domain.Meal>(
        AddMealRoute(
          retrospective: retrospective,
          initialEatenAt: retrospective ? calculatorDate : null,
        ),
      );
      await tester.pumpAndSettle();
      container.read(mealDraftProvider.notifier).setMealIngredients([
        mealFlowIngredient(container),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dalej: kiedy'));
      await tester.pumpAndSettle();
      final selected = retrospective
          ? calculatorDate.subtract(const Duration(minutes: 30))
          : DateTime.now().add(const Duration(hours: 1));
      // Exercise the same selection callback used by the date/time picker.
      tester
          .widget<MealTimingStep>(find.byType(MealTimingStep))
          .onDateChanged(selected);
      tester
          .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
          .didChange(selected);
      await tester.pumpAndSettle();
      if (retrospective) {
        // Restoring the calculator time remains available even after a manual change.
        await tester.tap(find.text('Użyj czasu wpisu kalkulatora'));
        await tester.pumpAndSettle();
        expect(container.read(mealDraftProvider).plannedAt, calculatorDate);
        tester
            .widget<MealTimingStep>(find.byType(MealTimingStep))
            .onDateChanged(selected);
        tester
            .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
            .didChange(selected);
        await tester.pumpAndSettle();
        final duration = find.widgetWithText(
          TextFormField,
          'Jak długo trwało jedzenie? (min)',
        );
        await tester.ensureVisible(duration);
        await tester.enterText(duration, '20');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final picker = find.byType(ManualMealDecisionPickerField);
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(ListTile, mealDecisionLabel(decision)),
        );
        await tester.pumpAndSettle();
        if (decision != MealDecision.bolusAndEatNow) {
          final input = find.widgetWithText(
            TextFormField,
            decision == MealDecision.bolusWaitThenEat
                ? lang.uiWaitingTimeAfterInsulinMin
                : lang.uiInsulinHowManyMinutesAfterEatingStarted,
          );
          await tester.ensureVisible(input);
          await tester.enterText(
            input,
            decision == MealDecision.bolusWaitThenEat ? '15' : '30',
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.text('Dalej: podsumowanie'));
      await tester.pumpAndSettle();
      expect(find.byType(MealReviewStep), findsOneWidget);
      expect(find.text('Carbs (netto)'), findsOneWidget);
      expect(find.text(lang.mealStartEcarbsLabel), findsOneWidget);
      final macros = await container.read(
        calculatedMacronutrientsProvider.future,
      );
      expect(find.text('${macros.extendedCarbsTotal} g'), findsWidgets);
      final tile = tester.widget<MealIngredientPreviewTile>(
        find.byType(MealIngredientPreviewTile),
      );
      expect(tile.onEdit, isNull);
      expect(tile.onRemove, isNull);
      container
          .read(mealDraftProvider.notifier)
          .setCategory(MealCategory.lunch);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(MealReviewName));
      await tester.tap(
        find.descendant(
          of: find.byType(MealReviewName),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Test meal');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // Back from review retains the selected time and manual decision fields.
      await tester.tap(find.text('Wstecz'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
            .value,
        selected,
      );
      if (retrospective) {
        expect(
          tester.widget<MealTimingStep>(find.byType(MealTimingStep)).anchor,
          MealTimeAnchor.insulin,
        );
        expect(find.text('20'), findsOneWidget);
        expect(
          tester
              .widget<ManualMealDecisionPickerField>(
                find.byType(ManualMealDecisionPickerField),
              )
              .value,
          decision,
        );
      }
      await tester.tap(find.text('Dalej: podsumowanie'));
      await tester.pumpAndSettle();
      expect(find.text('Test meal'), findsOneWidget);
      await tester.tap(
        find.text(retrospective ? 'Zapisz i przypisz' : 'Zaplanuj posiłek'),
      );
      // Database transactions run outside the fake clock.
      await tester.runAsync(() => result.timeout(const Duration(seconds: 10)));
      await tester.pumpAndSettle();
      expect(find.byType(AddMealPage), findsNothing);
      final meal = await result;
      expect(meal, isNotNull);
      final stored = await db.select(db.meal).getSingle();
      final expectedStart = decision == MealDecision.bolusWaitThenEat
          ? selected.add(const Duration(minutes: 15))
          : decision == MealDecision.eatNowBolusLater
          ? selected.subtract(const Duration(minutes: 30))
          : selected;
      expect(stored.plannedAt, expectedStart.millisecondsSinceEpoch);
      expect(stored.name, 'Test meal');
      expect(stored.status, retrospective ? 'summarized' : 'planned');
      if (retrospective) {
        final timing = RetrospectiveMealTiming(
          choice: ManualMealDecision(
            decision: decision,
            waitMinutes: decision == MealDecision.bolusWaitThenEat ? 15 : 0,
          ),
          eatingMinutes: 20,
          bolusAfterStartMinutes: decision == MealDecision.eatNowBolusLater
              ? 30
              : 0,
        );
        final history = await db.select(db.mealStatusHistory).get();
        final expected = timing.history(expectedStart);
        for (final entry in expected.entries) {
          expect(
            history.any(
              (row) =>
                  row.status == entry.key &&
                  row.createdAt == entry.value.millisecondsSinceEpoch,
            ),
            isTrue,
          );
        }
        final ingredient = await db.select(db.mealIngredients).getSingle();
        expect(ingredient.consumedAmount, ingredient.amount);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
