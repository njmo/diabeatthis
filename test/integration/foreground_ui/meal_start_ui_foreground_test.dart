import 'dart:async';

import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart'
    show IngredientCompanion, MealIngredientsCompanion;
import 'package:diabeatthis/core/drift/entity/meal.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/show_meal_status_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/foreground_ui/test_aaps_launcher.dart';

void main() {
  setUp(() => setLanguageStringsFromCode('en'));

  for (final scenario in [
    (
      name: 'food first',
      label: 'Food first, then insulin',
      status: 'eating-then-bolus',
      phase: MealMonitoringPhase.eatingThenBolus,
      wait: false,
      action: 'Start eating',
      initialWait: 0,
    ),
    (
      name: 'insulin and wait',
      label: 'Insulin, wait, eat',
      status: 'waiting-for-bolus',
      phase: MealMonitoringPhase.waitingForBolus,
      wait: true,
      action: 'Deliver bolus and wait',
      initialWait: 12,
    ),
    (
      name: 'insulin and food now',
      label: 'Insulin and food without waiting',
      status: 'waiting-for-bolus',
      phase: MealMonitoringPhase.waitingForBolus,
      wait: false,
      action: 'Deliver bolus',
      initialWait: 0,
    ),
  ]) {
    testWidgets(
      'manual ${scenario.name} decision saves through UI and reaches foreground',
      (tester) async {
        late final ForegroundUiHarness harness;
        late final int mealId;
        late final DateTime plannedAt;
        final actionCompleted = Completer<void>();
        await tester.runAsync(() async {
          harness = await ForegroundUiHarness.create(
            uiOverrides: [
              aapsLauncherProvider.overrideWithValue(const TestAapsLauncher()),
            ],
          );
          plannedAt = DateTime.now().add(const Duration(hours: 2));
          mealId = await _seedPlannedMeal(harness, plannedAt);
        });

        try {
          await _waitForPublishedPhase(
            tester,
            harness,
            mealId,
            MealMonitoringPhase.planned,
          );
          await _mountMealDialog(
            tester,
            harness,
            mealId,
            plannedAt,
            actionCompleted: actionCompleted,
          );
          await tester.tap(find.text('I will eat'));
          await _openManualDecision(tester);
          await tester.tap(find.text(scenario.label));
          await tester.pump();
          if (scenario.wait) {
            await _pumpUntil(
              tester,
              () => find.byType(TextFormField).evaluate().isNotEmpty,
            );
            await tester.enterText(find.byType(TextFormField), '12');
          }
          final manualSubmit = find.text('Next').evaluate().isNotEmpty
              ? find.text('Next')
              : find.text('Apply change');
          await tester.tap(manualSubmit);
          final startAction = scenario.action;
          await _pumpUntil(
            tester,
            () => find.text(startAction).evaluate().isNotEmpty,
          );
          await tester.tap(find.text(startAction));
          await _pumpForUiIo(tester);

          final persisted = await _waitForStatus(
            tester,
            harness,
            mealId,
            scenario.status,
            scenario.phase,
          );
          expect(persisted?.status, scenario.status);
          expect(persisted?.plannedAt, plannedAt.millisecondsSinceEpoch);
          expect(harness.mealStatus?.phase, scenario.phase);
          expect(harness.mealStatus?.mealId, mealId);
          await _pumpUntil(tester, () => actionCompleted.isCompleted);
          final advice = await tester.runAsync(
            () =>
                harness.uiDb.mealAdvisorResultDao.getMealAdvisorResult(mealId),
          );
          expect(advice?.result, 'manual');
          expect(advice?.initialWaitTime, scenario.initialWait);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(
            () => harness.close().timeout(const Duration(seconds: 5)),
          );
        }
      },
    );
  }

  testWidgets(
    'canceling the manual decision leaves the planned meal unchanged',
    (tester) async {
      late final ForegroundUiHarness harness;
      late final int mealId;
      late final DateTime plannedAt;
      final actionCompleted = Completer<void>();
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        plannedAt = DateTime.now().add(const Duration(hours: 2));
        mealId = await _seedPlannedMeal(harness, plannedAt);
      });

      try {
        await _waitForPublishedPhase(
          tester,
          harness,
          mealId,
          MealMonitoringPhase.planned,
        );
        await _mountMealDialog(
          tester,
          harness,
          mealId,
          plannedAt,
          actionCompleted: actionCompleted,
        );
        await tester.tap(find.text('I will eat'));
        await _openManualDecision(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(ManualMealDecisionDialog),
            matching: find.text('Cancel'),
          ),
        );
        await _pumpUntil(
          tester,
          () => find.byType(ManualMealDecisionDialog).evaluate().isEmpty,
        );
        await tester.tap(find.byIcon(Icons.close));
        await _pumpUntil(
          tester,
          () => find.text('Open planned meal').evaluate().isNotEmpty,
        );
        await _pumpUntil(tester, () => actionCompleted.isCompleted);
        final row = await _waitForUiMeal(tester, harness, mealId);
        expect(row?.status, 'planned');
        expect(harness.mealStatus?.mealId, mealId);
        expect(harness.mealStatus?.phase, MealMonitoringPhase.planned);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => harness.close().timeout(const Duration(seconds: 5)),
        );
      }
    },
  );
}

Future<int> _seedPlannedMeal(
  ForegroundUiHarness harness,
  DateTime plannedAt,
) async {
  final db = harness.uiDb;
  final ingredientId = await db
      .into(db.ingredient)
      .insert(
        IngredientCompanion.insert(
          name: 'Manual start integration food',
          carbsPer100g: 30,
          fiberPer100g: 2,
          fatPer100g: 8,
          proteinPer100g: 12,
          nutritionConfidence: .9,
        ),
      );
  final mealId = await db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: 'Manual start integration meal',
          plannedAt: plannedAt.millisecondsSinceEpoch,
          status: const Value('planned'),
        ),
      );
  await db
      .into(db.mealIngredients)
      .insert(
        MealIngredientsCompanion.insert(
          mealId: mealId,
          ingredientId: ingredientId,
          amount: const Value(100),
          quantityConfidence: .9,
        ),
      );
  harness.startMonitoring();
  return mealId;
}

Future<void> _mountMealDialog(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
  DateTime plannedAt, {
  required Completer<void> actionCompleted,
}) async {
  final meal = domain.Meal(
    id: mealId,
    name: 'Manual start integration meal',
    status: 'planned',
    plannedAt: plannedAt,
  );
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
              onPressed: () async {
                try {
                  final result = await showMealStatusDialog(
                    context: context,
                    meal: meal,
                  );
                  if (result != null && context.mounted) {
                    await handleMealStatusDialogResult(
                      context: context,
                      ref: ref,
                      meal: meal,
                      result: result,
                      openSummaryAfterEaten: false,
                    );
                  }
                } finally {
                  if (!actionCompleted.isCompleted) {
                    actionCompleted.complete();
                  }
                }
              },
              child: const Text('Open planned meal'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open planned meal'));
  await _pumpUntil(tester, () => find.text('I will eat').evaluate().isNotEmpty);
}

Future<void> _openManualDecision(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    () =>
        find.text('Choose a decision manually').evaluate().isNotEmpty ||
        find.text('Change decision').evaluate().isNotEmpty,
  );
  final manualButton = find.text('Choose a decision manually');
  await tester.tap(
    manualButton.evaluate().isNotEmpty
        ? manualButton
        : find.text('Change decision'),
  );
  await _pumpUntil(
    tester,
    () => find.byType(ManualMealDecisionDialog).evaluate().isNotEmpty,
  );
}

Future<void> _pumpForUiIo(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 150 && !condition(); i++) {
    await _pumpForUiIo(tester);
  }
  expect(condition(), isTrue);
}

Future<dynamic> _waitForStatus(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
  String expectedStatus,
  MealMonitoringPhase expectedPhase,
) async {
  dynamic latestRow;
  var querying = false;
  for (var i = 0; i < 100; i++) {
    if (!querying) {
      querying = true;
      harness.foregroundDb.mealDao.getMealById(mealId).then((row) {
        latestRow = row;
        querying = false;
      });
    }
    await _pumpForUiIo(tester);
    if (latestRow?.status == expectedStatus &&
        harness.mealStatus?.phase == expectedPhase) {
      return latestRow;
    }
  }
  fail(
    'Foreground did not publish persisted meal status $expectedStatus with phase $expectedPhase.',
  );
}

Future<dynamic> _waitForUiMeal(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
) async {
  dynamic latestRow;
  var querying = false;
  for (var attempt = 0; attempt < 100; attempt++) {
    if (!querying) {
      querying = true;
      harness.uiDb.mealDao.getMealById(mealId).then((row) {
        latestRow = row;
        querying = false;
      });
    }
    await _pumpForUiIo(tester);
    if (latestRow != null) return latestRow;
  }
  fail('The UI meal row was not readable after the cancellation flow.');
}

Future<void> _waitForPublishedPhase(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
  MealMonitoringPhase phase,
) async {
  for (var i = 0; i < 100; i++) {
    if (harness.mealStatus?.mealId == mealId &&
        harness.mealStatus?.phase == phase) {
      return;
    }
    await _pumpForUiIo(tester);
  }
  fail('Foreground did not publish meal $mealId with phase $phase.');
}
