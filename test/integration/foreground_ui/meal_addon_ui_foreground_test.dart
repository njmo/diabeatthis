import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/open_meal_add_on.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_status.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart'
    show IngredientCompanion, MealCompanion, MealIngredientsCompanion;
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_add_on_editor.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/foreground_ui/test_aaps_launcher.dart';

void main() {
  testWidgets(
    'canceling add-on leaves consumed amounts and eating status unchanged',
    (tester) async {
      final start = DateTime.now().subtract(const Duration(minutes: 20));
      late ForegroundUiHarness harness;
      late int mealId;
      await tester.runAsync(() async {
        harness = await _createHarness();
        mealId = await _seedMeal(harness, start);
        harness.startMonitoring();
      });
      try {
        final activeStatus = await _waitForPhase(
          tester,
          harness,
          mealId,
          MealMonitoringPhase.eating,
        );
        await _openAddOn(tester, harness, mealId);
        await tester.tap(find.text('Cancel'));
        await _pumpUi(tester);
        final rows = await tester.runAsync(
          () async => (
            await harness.uiDb.mealDao.getMealById(mealId),
            await harness.foregroundDb.mealDao.getMealById(mealId),
            await harness.uiDb.mealIngredientsDao.getMealIngredientsForMeal(
              mealId,
            ),
          ),
        );
        expect(rows!.$1?.status, 'eating');
        expect(rows.$2?.status, 'eating');
        expect(rows.$3.map((row) => row.consumedAmount), [100, 200]);
        expect(harness.mealStatus, activeStatus);

        await _openAddOn(tester, harness, mealId);
        await tester.tap(find.text('1.5× the whole meal'));
        await _pumpUi(tester);
        expect(find.byType(MealAddOnEditor), findsOneWidget);
        final back = find.byType(BackButton);
        await tester.tap(back);
        await _pumpUi(tester);
        final afterEditorCancel = await tester.runAsync(
          () async => (
            await harness.uiDb.mealDao.getMealById(mealId),
            await harness.uiDb.mealIngredientsDao.getMealIngredientsForMeal(
              mealId,
            ),
          ),
        );
        expect(afterEditorCancel!.$1?.status, 'eating');
        expect(afterEditorCancel.$2.map((row) => row.consumedAmount), [
          100,
          200,
        ]);
        expect(harness.mealStatus, activeStatus);
        expect(find.byType(MealCompletionView), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => harness.close().timeout(const Duration(seconds: 5)),
        );
      }
    },
  );

  for (final scenario in [
    (status: 'eating', coveredCarbs: 0, requestedCarbs: 60),
    (status: 'bolused-eating', coveredCarbs: 40, requestedCarbs: 20),
  ]) {
    testWidgets(
      'larger-portion add-on from ${scenario.status} preserves coverage and stores each amount once',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(minutes: 20));
        late ForegroundUiHarness harness;
        late int mealId;
        await tester.runAsync(() async {
          harness = await _createHarness();
          mealId = await _seedMeal(harness, start, status: scenario.status);
          harness.startMonitoring();
        });
        try {
          await _openAddOn(tester, harness, mealId, status: scenario.status);
          await tester.tap(find.text('1.5× the whole meal'));
          await _pumpUi(tester);
          expect(find.byType(MealAddOnEditor), findsOneWidget);
          final confirm = find.widgetWithText(
            FilledButton,
            'I’m eating the extra food',
          );
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pump();
          // The real editor disables its save action while the transaction runs.
          await tester.tap(confirm, warnIfMissed: false);
          await _waitForStatus(tester, harness, mealId, 'eating-extra');
          await _pumpUi(tester);
          final rows = await tester.runAsync(
            () async => (
              await harness.uiDb.mealIngredientsDao.getMealIngredientsForMeal(
                mealId,
              ),
              await harness.foregroundDb.mealIngredientsDao
                  .getMealIngredientsForMeal(mealId),
              await harness.foregroundDb.ingredientDao.totalsForMealConsumed(
                mealId,
              ),
              await harness.foregroundDb.mealDao.getMealById(mealId),
            ),
          );
          expect(rows!.$1.map((row) => row.consumedAmount), [150, 300]);
          expect(rows.$2.map((row) => row.consumedAmount), [150, 300]);
          expect(rows.$3!.netCarbsGrams, 60); // (100g × 20g + 200g × 10g) × 1.5
          expect(rows.$4?.status, 'eating-extra');
          final pendingBolus = MealAddOnBolusContext.decode(
            rows.$4?.addOnBolusContext,
          );
          expect(pendingBolus?.awaitingBolus, isTrue);
          expect(pendingBolus?.coveredCarbs, scenario.coveredCarbs);
          expect(pendingBolus?.requestedCarbs, scenario.requestedCarbs);
          expect(
            harness.mealStatus?.phase,
            MealMonitoringPhase.waitingForBolus,
          );
          expect(harness.mealStatus?.mealId, mealId);
          expect(find.byType(MealAddOnEditor), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(
            () => harness.close().timeout(const Duration(seconds: 5)),
          );
        }
      },
    );
  }
}

Future<ForegroundUiHarness> _createHarness() => ForegroundUiHarness.create(
  uiOverrides: [
    aapsLauncherProvider.overrideWithValue(const TestAapsLauncher()),
  ],
);

Future<int> _seedMeal(
  ForegroundUiHarness harness,
  DateTime start, {
  String status = 'eating',
}) async {
  final db = harness.uiDb;
  final rice = await db
      .into(db.ingredient)
      .insert(
        IngredientCompanion.insert(
          name: 'Integration rice',
          carbsPer100g: 20,
          fiberPer100g: 0,
          fatPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: .9,
        ),
      );
  final beans = await db
      .into(db.ingredient)
      .insert(
        IngredientCompanion.insert(
          name: 'Integration beans',
          carbsPer100g: 10,
          fiberPer100g: 0,
          fatPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: .9,
        ),
      );
  final mealId = await db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: 'Integration lunch',
          plannedAt: start.millisecondsSinceEpoch,
          status: Value(status),
        ),
      );
  for (final row in [(rice, 100.0), (beans, 200.0)]) {
    await db
        .into(db.mealIngredients)
        .insert(
          MealIngredientsCompanion.insert(
            mealId: mealId,
            ingredientId: row.$1,
            amount: Value(row.$2),
            quantityConfidence: .9,
            consumedAmount: Value(row.$2),
            consumedConfidence: const Value(.9),
          ),
        );
  }
  return mealId;
}

Future<void> _openAddOn(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int id, {
  String status = 'eating',
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.uiContainer,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => openMealAddOn(
                context: context,
                ref: ref,
                meal: domain.Meal(
                  id: id,
                  name: 'Integration lunch',
                  status: status,
                ),
              ),
              child: const Text('Open add-on'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open add-on'));
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (find.text('1.5× the whole meal').evaluate().isNotEmpty) return;
  }
  expect(find.text('1.5× the whole meal'), findsOneWidget);
}

Future<void> _pumpUi(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

Future<void> _waitForStatus(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int id,
  String expected,
) async {
  String? observed;
  var pending = false;
  for (var i = 0; i < 200; i++) {
    if (!pending) {
      pending = true;
      harness.foregroundDb.mealDao.getMealById(id).then((meal) {
        observed = meal?.status;
        pending = false;
      });
    }
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (observed == expected) return;
  }
  expect(
    observed,
    expected,
    reason: 'The foreground database client must observe the UI transaction.',
  );
}

Future<MealMonitoringStatus> _waitForPhase(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int id,
  MealMonitoringPhase phase,
) async {
  for (var i = 0; i < 100; i++) {
    final status = harness.mealStatus;
    if (status?.phase == phase && status?.mealId == id) return status!;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  final status = harness.mealStatus;
  expect(status?.phase, phase);
  expect(status?.mealId, id);
  throw StateError('Meal monitor did not publish $phase for meal $id.');
}
