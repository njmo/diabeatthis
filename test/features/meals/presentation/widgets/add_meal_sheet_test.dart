import 'package:auto_route/auto_route.dart';
import 'package:diabeatthis/app/router/app_router.dart';
import 'package:diabeatthis/app/router/guards/initial_configuration_guard.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_composition_step.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_planned_time_field.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_review_step.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_timing_step.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  for (final retrospective in [false, true]) {
    testWidgets(
      'meal sheet scrolls, handles keyboard and returns a saved meal (past: $retrospective)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final configuredRoutes = container.read(
          Provider((ref) => AppRouter(InitialConfigurationGuard(ref)).routes),
        );
        final router = RootStackRouter.build(
          routes: [
            NamedRouteDef(
              name: 'TestHome',
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Home')),
            ),
            configuredRoutes.firstWhere(
              (route) => route.page.name == AddMealRoute.name,
            ),
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
        final reference = DateTime(2025, 11, 2, 12);
        final result = router.push<domain.Meal>(
          AddMealRoute(
            retrospective: retrospective,
            initialEatenAt: retrospective ? reference : null,
          ),
        );
        await tester.pumpAndSettle();
        final page = find.byType(AddMealPage);
        expect(
          ModalRoute.of(tester.element(page)),
          isA<ModalBottomSheetRoute<domain.Meal>>(),
        );
        expect(tester.getTopLeft(page).dy, greaterThan(40));
        expect(tester.getSize(page).height, lessThan(700));
        final draft = container.read(mealDraftProvider.notifier);
        draft.setMealIngredients([mealFlowIngredient(container)]);
        draft.setName('Sheet meal');
        draft.setCategory(MealCategory.lunch);
        await tester.pumpAndSettle();
        // A nested picker closes independently without losing the meal sheet.
        final nested = showModalBottomSheet<void>(
          context: tester.element(page),
          builder: (context) => TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close picker'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close picker'));
        await tester.pumpAndSettle();
        await nested;
        expect(page, findsOneWidget);
        expect(container.read(mealDraftProvider).mealIngredients, hasLength(1));
        await tester.tap(find.text('Dalej: kiedy'));
        await tester.pumpAndSettle();
        // Platform back goes to the prior step instead of dismissing the sheet.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MealCompositionStep), findsOneWidget);
        expect(page, findsOneWidget);
        await tester.tap(find.text('Dalej: kiedy'));
        await tester.pumpAndSettle();
        if (retrospective) {
          final duration = find.widgetWithText(
            TextFormField,
            'Jak długo trwało jedzenie? (min)',
          );
          await tester.ensureVisible(duration);
          await tester.enterText(duration, '15');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
        } else {
          final selected = DateTime.now().add(const Duration(hours: 1));
          tester
              .widget<MealTimingStep>(find.byType(MealTimingStep))
              .onDateChanged(selected);
          tester
              .state<FormFieldState<DateTime>>(
                find.byType(MealPlannedTimeField),
              )
              .didChange(selected);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Dalej: podsumowanie'));
        await tester.pumpAndSettle();
        expect(find.byType(MealReviewStep), findsOneWidget);
        tester.view.viewInsets = FakeViewPadding(
          bottom: 280 * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final save = find.widgetWithText(
          FilledButton,
          retrospective ? 'Zapisz i przypisz' : 'Zaplanuj posiłek',
        );
        expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(420));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.tap(save);
        final saved = await tester.runAsync(
          () => result.timeout(const Duration(seconds: 10)),
        );
        await tester.pumpAndSettle();
        expect(saved?.name, 'Sheet meal');
        expect(saved?.category, MealCategory.lunch);
        expect((await db.select(db.meal).getSingle()).category, 'lunch');
        expect(saved?.status, retrospective ? 'summarized' : 'planned');
        expect(page, findsNothing);
        expect(router.stack, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
