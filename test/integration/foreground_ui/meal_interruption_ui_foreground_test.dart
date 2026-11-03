import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/common/widgets/meal_progress/active_meal_progress_card.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show
        IngredientCompanion,
        MealCompanion,
        MealIngredientsCompanion,
        MealStatusHistoryCompanion;
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list_today.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/idle_executor.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';

void main() {
  setUp(() => setLanguageStringsFromCode('en'));
  testWidgets(
    'canceling interruption leaves both clients and meal data unchanged',
    (tester) async {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 20));
      late ForegroundUiHarness harness;
      late int mealId;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        mealId = await _seedEatingMeal(harness, startedAt);
        harness.startMonitoring();
      });
      try {
        await _showMealList(tester, harness);
        await _waitForCard(tester);
        final before = await _readMealData(tester, harness, mealId);
        final activeStatus = await _waitForMealPhase(
          tester,
          harness,
          mealId,
          MealMonitoringPhase.eating,
        );

        await _openInterruption(tester);
        await tester.tap(find.text('Cancel'));
        await _pumpUi(tester);

        final after = await _readMealData(tester, harness, mealId);
        expect(after.uiMeal?.status, 'eating');
        expect(after.foregroundMeal?.status, 'eating');
        expect(after.uiHistory, before.uiHistory);
        expect(after.foregroundHistory, before.foregroundHistory);
        expect(after.uiSnapshots, before.uiSnapshots);
        expect(after.foregroundSnapshots, before.foregroundSnapshots);
        expect(harness.mealStatus, activeStatus);
        expect(harness.mealMonitor.state, isNot(isA<MealMonitorStateIdle>()));
        expect(find.byType(ActiveMealProgressCard), findsOneWidget);
      } finally {
        await _closeHarness(tester, harness);
      }
    },
  );

  testWidgets(
    'confirming interruption commits once and removes the active card',
    (tester) async {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 20));
      late ForegroundUiHarness harness;
      late int mealId;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        mealId = await _seedEatingMeal(harness, startedAt);
        harness.startMonitoring();
      });
      try {
        await _showMealList(tester, harness);
        await _waitForCard(tester);
        await _openInterruption(tester);
        await tester.tap(find.text('Stop tracking'));

        await _waitForStatus(tester, harness, mealId, 'interrupted');
        await _pumpUi(tester);
        final rows = await _readMealData(tester, harness, mealId);
        expect(rows.uiMeal?.status, 'interrupted');
        expect(rows.foregroundMeal?.status, 'interrupted');
        expect(
          rows.uiHistory.where((row) => row.status == 'interrupted'),
          hasLength(1),
        );
        expect(
          rows.foregroundHistory.where((row) => row.status == 'interrupted'),
          hasLength(1),
        );
        expect(rows.uiSnapshots, isEmpty);
        expect(rows.foregroundSnapshots, isEmpty);
        expect(harness.mealMonitor.state, isA<MealMonitorStateIdle>());
        expect(harness.mealStatus?.phase, MealMonitoringPhase.idle);
        expect(harness.mealStatus?.mealId, equals(null));
        expect(find.byType(ActiveMealProgressCard), findsNothing);
        expect(find.text('Integration lunch'), findsNothing);
      } finally {
        await _closeHarness(tester, harness);
      }
    },
  );

  testWidgets(
    'a stale interruption confirmation cannot overwrite a terminal meal',
    (tester) async {
      final startedAt = DateTime.now().subtract(const Duration(minutes: 20));
      late ForegroundUiHarness harness;
      late int mealId;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        mealId = await _seedEatingMeal(harness, startedAt);
        harness.startMonitoring();
      });
      try {
        await _showMealList(tester, harness);
        await _waitForCard(tester);
        await _openInterruption(tester);
        await tester.runAsync(() async {
          await harness.foregroundDb.mealDao.updateMealStatus(
            mealId,
            'eaten',
            occurredAt: DateTime.now(),
          );
        });
        await tester.tap(find.text('Stop tracking'));
        await _waitForStatus(tester, harness, mealId, 'eaten');
        await _pumpUi(tester);

        final rows = await _readMealData(tester, harness, mealId);
        expect(rows.uiMeal?.status, 'eaten');
        expect(rows.foregroundMeal?.status, 'eaten');
        expect(
          rows.uiHistory.where((row) => row.status == 'interrupted'),
          isEmpty,
        );
        expect(
          rows.foregroundHistory.where((row) => row.status == 'interrupted'),
          isEmpty,
        );
        expect(
          rows.uiHistory.where((row) => row.status == 'eaten'),
          hasLength(1),
        );
        expect(
          rows.foregroundHistory.where((row) => row.status == 'eaten'),
          hasLength(1),
        );
        expect(harness.mealMonitor.state, isA<MealMonitorStateIdle>());
        expect(find.byType(ActiveMealProgressCard), findsNothing);
      } finally {
        await _closeHarness(tester, harness);
      }
    },
  );

  testWidgets(
    'cold restore keeps the active UI meal aligned with foreground monitoring',
    (tester) async {
      final now = DateTime.now();
      late ForegroundUiHarness harness;
      late int activeMealId;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        activeMealId = await _seedEatingMeal(
          harness,
          now.subtract(const Duration(minutes: 30)),
        );
        await _seedCompletedMeal(
          harness,
          now.subtract(const Duration(minutes: 5)),
        );
        harness.startMonitoring();
      });
      try {
        await _showMealList(tester, harness);
        await _waitForCard(tester);
        final status = await _waitForMealPhase(
          tester,
          harness,
          activeMealId,
          MealMonitoringPhase.eating,
        );
        expect(status.mealId, activeMealId);
        expect(find.text('Integration lunch'), findsOneWidget);
        expect(find.byType(ActiveMealProgressCard), findsOneWidget);
      } finally {
        await _closeHarness(tester, harness);
      }
    },
  );
}

Future<int> _seedEatingMeal(
  ForegroundUiHarness harness,
  DateTime startedAt,
) async {
  final db = harness.uiDb;
  final ingredientId = await db
      .into(db.ingredient)
      .insert(
        IngredientCompanion.insert(
          name: 'Interruption test rice',
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
          status: const Value('eating'),
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

Future<void> _seedCompletedMeal(
  ForegroundUiHarness harness,
  DateTime time,
) async {
  final db = harness.uiDb;
  final id = await db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: 'Earlier finished meal',
          plannedAt: time.millisecondsSinceEpoch,
          status: const Value('eaten'),
        ),
      );
  await db
      .into(db.mealStatusHistory)
      .insert(
        MealStatusHistoryCompanion.insert(
          mealId: id,
          status: 'eaten',
          createdAt: Value(time.millisecondsSinceEpoch),
        ),
      );
}

Future<void> _showMealList(
  WidgetTester tester,
  ForegroundUiHarness harness,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.uiContainer,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: MealListToday()),
        ),
      ),
    ),
  );
  await _pumpUi(tester);
}

Future<void> _waitForCard(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (find.byType(ActiveMealProgressCard).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(find.byType(ActiveMealProgressCard), findsOneWidget);
}

Future<void> _openInterruption(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Interrupt meal tracking'));
  await tester.pump();
  expect(find.text('Stop tracking this meal?'), findsOneWidget);
}

Future<void> _waitForStatus(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int id,
  String expected,
) async {
  String? observed;
  var querying = false;
  for (var attempt = 0; attempt < 200; attempt++) {
    if (!querying) {
      querying = true;
      harness.foregroundDb.mealDao.getMealById(id).then((meal) {
        observed = meal?.status;
        querying = false;
      });
    }
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (observed == expected) return;
  }
  expect(observed, expected);
}

Future<dynamic> _waitForMealPhase(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
  MealMonitoringPhase phase,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final status = harness.mealStatus;
    if (status?.mealId == mealId && status?.phase == phase) return status;
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(harness.mealStatus?.mealId, mealId);
  expect(harness.mealStatus?.phase, phase);
  return harness.mealStatus;
}

Future<_MealData> _readMealData(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int id,
) async {
  return (await tester.runAsync(() async {
    final uiHistory = await (harness.uiDb.select(
      harness.uiDb.mealStatusHistory,
    )..where((row) => row.mealId.equals(id))).get();
    final foregroundHistory = await (harness.foregroundDb.select(
      harness.foregroundDb.mealStatusHistory,
    )..where((row) => row.mealId.equals(id))).get();
    final uiSnapshots = await (harness.uiDb.select(
      harness.uiDb.mealSnapshot,
    )..where((row) => row.mealId.equals(id))).get();
    final foregroundSnapshots = await (harness.foregroundDb.select(
      harness.foregroundDb.mealSnapshot,
    )..where((row) => row.mealId.equals(id))).get();
    return _MealData(
      await harness.uiDb.mealDao.getMealById(id),
      await harness.foregroundDb.mealDao.getMealById(id),
      uiHistory,
      foregroundHistory,
      uiSnapshots,
      foregroundSnapshots,
    );
  }))!;
}

Future<void> _pumpUi(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

Future<void> _closeHarness(
  WidgetTester tester,
  ForegroundUiHarness harness,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(
    () => harness.close().timeout(const Duration(seconds: 5)),
  );
}

class _MealData {
  final dynamic uiMeal;
  final dynamic foregroundMeal;
  final List<dynamic> uiHistory;
  final List<dynamic> foregroundHistory;
  final List<dynamic> uiSnapshots;
  final List<dynamic> foregroundSnapshots;

  const _MealData(
    this.uiMeal,
    this.foregroundMeal,
    this.uiHistory,
    this.foregroundHistory,
    this.uiSnapshots,
    this.foregroundSnapshots,
  );
}
