import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/open_meal_completion.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_status.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show MealIngredientsCompanion, MealStatusHistoryCompanion;
import 'package:diabeatthis/core/drift/entity/ingredient.dart';
import 'package:diabeatthis/core/drift/entity/meal.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';

void main() {
  testWidgets('meal completion UI saves planned amount to both DB clients', (
    tester,
  ) async {
    final endedAt = DateTime.now();
    final startedAt = endedAt.subtract(const Duration(minutes: 30));
    late ForegroundUiHarness harness;
    late int id;
    await tester.runAsync(() async {
      harness = await _createHarness();
      id = await _seedEatingMeal(harness, startedAt);
      harness.startMonitoring();
    });
    try {
      await withClock(Clock.fixed(endedAt), () async {
        await _openCompletion(tester, harness, id, endedAt);
        await tester.tap(find.text('Everything'));
        await tester.pump();
        await tester.tap(find.text('Everything'), warnIfMissed: false);
        await tester.pump();
      });

      await _waitForStatus(tester, harness, id, 'summarized');
      await _pumpUi(tester);
      final records = await tester.runAsync(() async {
        return (
          await harness.uiDb.mealIngredientsDao.getMealIngredientsForMeal(id),
          await harness.foregroundDb.mealIngredientsDao
              .getMealIngredientsForMeal(id),
          await harness.foregroundDb.mealDao.getMealById(id),
        );
      });
      expect(records!.$1.single.consumedAmount, 100);
      expect(records.$2.single.consumedAmount, 100);
      expect(records.$3?.status, 'summarized');
      expect(harness.mealMonitor.state, isA<MealMonitorStateIdle>());
      expect(find.byType(MealCompletionView), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => harness.close().timeout(const Duration(seconds: 5)),
      );
    }
  });

  testWidgets(
    'adjusted meal completion saves less and more from the real editor',
    (tester) async {
      for (final amount in [80.0, 120.0]) {
        final endedAt = DateTime.now();
        final startedAt = endedAt.subtract(const Duration(minutes: 30));
        late ForegroundUiHarness harness;
        late int id;
        await tester.runAsync(() async {
          harness = await _createHarness();
          id = await _seedEatingMeal(harness, startedAt);
          harness.startMonitoring();
        });
        try {
          await withClock(Clock.fixed(endedAt), () async {
            await _openCompletion(tester, harness, id, endedAt);
            await tester.tap(find.text('Different'));
            await _pumpUi(tester);
            expect(find.byType(FriendlyAmountSelector), findsOneWidget);
            for (var i = 0; i < 4; i++) {
              await tester.tap(find.byTooltip(amount < 100 ? 'Less' : 'More'));
              await tester.pump();
            }
            await tester.pump();
            final save = find.widgetWithText(FilledButton, 'Save summary');
            await tester.ensureVisible(save);
            await tester.tap(save);
          });
          await _waitForStatus(tester, harness, id, 'summarized');
          await _pumpUi(tester);
          final records = await tester.runAsync(() async {
            return (
              await harness.uiDb.mealIngredientsDao.getMealIngredientsForMeal(
                id,
              ),
              await harness.foregroundDb.mealIngredientsDao
                  .getMealIngredientsForMeal(id),
              await harness.foregroundDb.ingredientDao.totalsForMealConsumed(
                id,
              ),
            );
          });
          expect(records!.$1.single.consumedAmount, amount);
          expect(records.$2.single.consumedAmount, amount);
          expect(records.$3!.netCarbsGrams, amount * .2);
          expect(harness.mealMonitor.state, isA<MealMonitorStateIdle>());
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(
            () => harness.close().timeout(const Duration(seconds: 5)),
          );
        }
      }
    },
  );

  testWidgets(
    'canceling the completion choice leaves the meal and monitor unchanged',
    (tester) async {
      final endedAt = DateTime.now();
      final startedAt = endedAt.subtract(const Duration(minutes: 30));
      late ForegroundUiHarness harness;
      late int id;
      await tester.runAsync(() async {
        harness = await _createHarness();
        id = await _seedEatingMeal(harness, startedAt);
        harness.startMonitoring();
      });
      try {
        final activeStatus = await _waitForMealStatus(
          tester,
          harness,
          id,
          MealMonitoringPhase.eating,
        );
        await withClock(Clock.fixed(endedAt), () async {
          await _openCompletion(tester, harness, id, endedAt);
          await tester.tap(find.byTooltip('Close'));
          await _pumpUi(tester);
        });
        final records = await tester.runAsync(() async {
          return (
            await harness.uiDb.mealDao.getMealById(id),
            await harness.foregroundDb.mealDao.getMealById(id),
            await harness.foregroundDb.mealIngredientsDao
                .getMealIngredientsForMeal(id),
          );
        });
        expect(records!.$1?.status, 'eating');
        expect(records.$2?.status, 'eating');
        expect(records.$3.single.consumedAmount, 100);
        expect(harness.mealStatus, activeStatus);
        expect(find.text('Open meal'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => harness.close().timeout(const Duration(seconds: 5)),
        );
      }
    },
  );

  testWidgets(
    'eating-then-bolus completion preserves eaten macros and waits for bolus',
    (tester) async {
      final endedAt = DateTime.now();
      final startedAt = endedAt.subtract(const Duration(minutes: 30));
      late ForegroundUiHarness harness;
      late int id;
      await tester.runAsync(() async {
        harness = await _createHarness();
        id = await _seedEatingMeal(
          harness,
          startedAt,
          status: 'eating-then-bolus',
        );
        harness.startMonitoring();
      });
      try {
        await withClock(Clock.fixed(endedAt), () async {
          await _openCompletion(tester, harness, id, endedAt);
          await tester.tap(find.text('Everything'));
          await tester.pump();
        });

        await _waitForStatus(tester, harness, id, 'waiting-for-bolus');
        await _pumpUi(tester);
        final records = await tester.runAsync(() async {
          final meal = await harness.foregroundDb.mealDao.getMealById(id);
          final items = await harness.foregroundDb.mealIngredientsDao
              .getMealIngredientsForMeal(id);
          final macros = await harness.foregroundDb.ingredientDao
              .totalsForMealConsumed(id);
          final history = await (harness.foregroundDb.select(
            harness.foregroundDb.mealStatusHistory,
          )..where((row) => row.mealId.equals(id))).get();
          final snapshots = await (harness.foregroundDb.select(
            harness.foregroundDb.mealSnapshot,
          )..where((row) => row.mealId.equals(id))).get();
          return (meal, items, macros, history, snapshots);
        });
        expect(records!.$1?.status, 'waiting-for-bolus');
        expect(records.$2.single.consumedAmount, 100);
        expect(records.$3!.netCarbsGrams, 20);
        expect(records.$4.map((entry) => entry.status), [
          'eating',
          'eating-then-bolus',
          'waiting-for-bolus',
        ]);
        final consumedSnapshot = records.$5.singleWhere(
          (snapshot) => snapshot.snapshotType == 'consumed',
        );
        expect(consumedSnapshot.totalCarbsG, 20);
        expect(harness.mealMonitor.state, isA<WaitForBolusExecutor>());
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => harness.close().timeout(const Duration(seconds: 5)),
        );
      }
    },
  );
}

Future<int> _seedEatingMeal(
  ForegroundUiHarness harness,
  DateTime startedAt, {
  String status = 'eating',
}) async {
  final db = harness.uiDb;
  final ingredientId = await db
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
  final mealId = await db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: 'Integration lunch',
          plannedAt: startedAt.millisecondsSinceEpoch,
          status: Value(status),
        ),
      );
  await db
      .into(db.mealStatusHistory)
      .insert(
        MealStatusHistoryCompanion.insert(
          mealId: mealId,
          status: 'eating',
          createdAt: Value(startedAt.millisecondsSinceEpoch),
        ),
      );
  if (status != 'eating') {
    await db
        .into(db.mealStatusHistory)
        .insert(
          MealStatusHistoryCompanion.insert(
            mealId: mealId,
            status: status,
            createdAt: Value(
              startedAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
            ),
          ),
        );
  }
  await db
      .into(db.mealIngredients)
      .insert(
        MealIngredientsCompanion.insert(
          mealId: mealId,
          ingredientId: ingredientId,
          amount: const Value(100),
          quantityConfidence: .9,
          consumedAmount: const Value(100),
          consumedConfidence: const Value(.9),
        ),
      );
  return mealId;
}

Future<ForegroundUiHarness> _createHarness() => ForegroundUiHarness.create(
  uiOverrides: [
    aapsLauncherProvider.overrideWithValue(const TestAapsLauncher()),
  ],
);

class TestAapsLauncher extends AapsLauncher {
  const TestAapsLauncher();

  @override
  Future<AapsLaunchResult> openAaps() async => AapsLaunchResult.opened;
}

Future<void> _openCompletion(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
  DateTime endedAt,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.uiContainer,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openMealCompletion(
                context,
                mealId: mealId,
                confirmedEatingEndedAt: endedAt,
              ),
              child: const Text('Open meal'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open meal'));
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (find.text('Everything').evaluate().isNotEmpty) return;
  }
  expect(find.text('Everything'), findsOneWidget);
}

Future<void> _pumpUi(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _waitForStatus(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
  String status,
) async {
  String? latestStatus;
  var querying = false;
  for (var attempt = 0; attempt < 200; attempt++) {
    if (!querying) {
      querying = true;
      harness.foregroundDb.mealDao.getMealById(mealId).then((row) {
        latestStatus = row?.status;
        querying = false;
      });
    }
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (latestStatus == status) return;
  }
  expect(
    latestStatus,
    status,
    reason: 'UI write must commit and become visible to foreground',
  );
}

Future<MealMonitoringStatus> _waitForMealStatus(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
  MealMonitoringPhase phase,
) async {
  for (var i = 0; i < 100; i++) {
    final status = harness.mealStatus;
    if (status?.phase == phase && status?.mealId == mealId) return status!;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  }
  final status = harness.mealStatus;
  expect(status?.phase, phase);
  expect(status?.mealId, mealId);
  if (status == null) {
    throw StateError('No meal monitoring status was published.');
  }
  return status;
}
