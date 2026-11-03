import 'package:auto_route/auto_route.dart';
import 'package:diabeatthis/app/router/app_router.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/common/widgets/meal_category_field.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_planned_time_field.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_timing_step.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_preview_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/meal_flow_test_fixture.dart';

void main() {
  testWidgets(
    'saving the real meal review persists and starts foreground monitoring',
    (tester) async {
      late ForegroundUiHarness harness;
      late RootStackRouter router;
      try {
        await tester.runAsync(() async {
          harness = await ForegroundUiHarness.create();
          final ingredient = mealFlowIngredient(harness.uiContainer);
          harness.uiContainer
              .read(mealDraftProvider.notifier)
              .setMealIngredients([ingredient]);
          harness.startMonitoring();
          router = _createRouter();
        });

        await _openMealReview(tester, harness, router);
        _expectIdleSaveButton(tester);
        final lang = lookupAppLocalizations(const Locale('pl'));
        await tester.tap(find.byType(MealCategoryField));
        await tester.pumpAndSettle();
        await tester.tap(find.text(MealCategory.lunch.label(lang)).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(lang.mealFlowPlan));
        final meal = await _waitForMeal(tester, harness);
        expect(meal, isNotNull);
        expect(meal!.status, 'planned');
        expect(
          meal.plannedAt,
          greaterThan(DateTime.now().millisecondsSinceEpoch),
        );
        final result = await tester.runAsync(() async {
          return (
            await harness.foregroundDb.mealDao.getMealById(meal.id),
            await harness.foregroundDb.mealIngredientsDao
                .getMealIngredientsForMeal(meal.id),
          );
        });
        expect(result!.$1?.status, 'planned');
        expect(result.$2, hasLength(1));
        await _waitForPlannedMonitor(tester, harness, meal.id);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => harness.close());
        router.dispose();
      }
    },
  );

  testWidgets('canceling before final save creates no meal or monitor entry', (
    tester,
  ) async {
    late ForegroundUiHarness harness;
    late RootStackRouter router;
    try {
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        harness.uiContainer.read(mealDraftProvider.notifier).setMealIngredients(
          [mealFlowIngredient(harness.uiContainer)],
        );
        harness.startMonitoring();
        router = _createRouter();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.uiContainer,
          child: MaterialApp.router(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router.config(),
          ),
        ),
      );
      router.push(AddMealRoute());
      await tester.pumpAndSettle();
      await _advanceToReview(tester);
      // The page back action returns through each step; the last action exits.
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(find.byType(AddMealPage), findsNothing);
      final rows = await tester.runAsync(() async {
        return (
          await harness.uiDb.select(harness.uiDb.meal).get(),
          await harness.foregroundDb.select(harness.foregroundDb.meal).get(),
        );
      });
      expect(rows!.$1, isEmpty);
      expect(rows.$2, isEmpty);
      expect(harness.mealStatus?.phase, MealMonitoringPhase.idle);
      expect(harness.mealStatus?.mealId, isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => harness.close());
      router.dispose();
    }
  });

  testWidgets('rapid final-save taps persist one meal', (tester) async {
    late ForegroundUiHarness harness;
    late RootStackRouter router;
    try {
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        harness.uiContainer.read(mealDraftProvider.notifier).setMealIngredients(
          [mealFlowIngredient(harness.uiContainer)],
        );
        harness.startMonitoring();
        router = _createRouter();
      });
      await _openMealReview(tester, harness, router);
      _expectIdleSaveButton(tester);
      final lang = lookupAppLocalizations(const Locale('pl'));
      await tester.tap(find.byType(MealCategoryField));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MealCategory.lunch.label(lang)).last);
      await tester.pumpAndSettle();
      final save = find.text(lang.mealFlowPlan);
      await tester.tap(save);
      await tester.tap(save, warnIfMissed: false);
      final meal = await _waitForMeal(tester, harness);
      expect(meal, isNotNull);
      final pair = await _waitForSharedMeal(tester, harness, meal!.id);
      expect(pair.$1, hasLength(1));
      expect(pair.$2, hasLength(1));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => harness.close());
      router.dispose();
    }
  });
}

Future<void> _openMealReview(
  WidgetTester tester,
  ForegroundUiHarness harness,
  RootStackRouter router,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.uiContainer,
      child: MaterialApp.router(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push(AddMealRoute());
  await tester.pumpAndSettle();
  await _advanceToReview(tester);
}

RootStackRouter _createRouter() => RootStackRouter.build(
  routes: [
    NamedRouteDef(
      name: 'TestHome',
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('Home')),
    ),
    AutoRoute(page: AddMealRoute.page),
  ],
);

Future<void> _advanceToReview(WidgetTester tester) async {
  expect(find.byType(CircularProgressIndicator), findsNothing);
  await tester.tap(find.text('Dalej: kiedy'));
  await tester.pumpAndSettle();
  final plannedAt = DateTime.now().add(const Duration(hours: 2));
  final timingStep = tester.widget<MealTimingStep>(find.byType(MealTimingStep));
  timingStep.onDateChanged(plannedAt);
  tester
      .state<FormFieldState<DateTime>>(find.byType(MealPlannedTimeField))
      .didChange(plannedAt);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dalej: podsumowanie'));
  await tester.pumpAndSettle();
  expect(find.byType(MealIngredientPreviewTile), findsOneWidget);
}

Future<void> _waitForPlannedMonitor(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (harness.mealStatus?.phase == MealMonitoringPhase.planned &&
        harness.mealStatus?.mealId == mealId) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(harness.mealStatus?.phase, MealMonitoringPhase.planned);
  expect(harness.mealStatus?.mealId, mealId);
}

void _expectIdleSaveButton(WidgetTester tester) {
  expect(find.byType(CircularProgressIndicator), findsNothing);
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Zaplanuj posiłek'),
  );
  expect(button.onPressed, isNotNull);
}

Future<dynamic> _waitForMeal(
  WidgetTester tester,
  ForegroundUiHarness harness,
) async {
  dynamic latestMeal;
  var querying = false;
  for (var attempt = 0; attempt < 200; attempt++) {
    if (!querying) {
      querying = true;
      harness.uiDb.select(harness.uiDb.meal).get().then((rows) {
        if (rows.isNotEmpty) latestMeal = rows.first;
        querying = false;
      });
    }
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (latestMeal != null) return latestMeal;
  }
  return latestMeal;
}

Future<(List<dynamic>, List<dynamic>)> _waitForSharedMeal(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
) async {
  List<dynamic>? uiRows;
  List<dynamic>? foregroundRows;
  var querying = false;
  for (var attempt = 0; attempt < 200; attempt++) {
    if (!querying) {
      querying = true;
      Future.wait([
        harness.uiDb.select(harness.uiDb.meal).get(),
        harness.foregroundDb.select(harness.foregroundDb.meal).get(),
      ]).then((rows) {
        uiRows = rows[0].where((row) => row.id == mealId).toList();
        foregroundRows = rows[1].where((row) => row.id == mealId).toList();
        querying = false;
      });
    }
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (uiRows?.length == 1 && foregroundRows?.length == 1) {
      return (uiRows!, foregroundRows!);
    }
  }
  return (uiRows ?? [], foregroundRows ?? []);
}
