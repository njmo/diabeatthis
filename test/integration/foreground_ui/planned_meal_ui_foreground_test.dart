import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/core/data/provider/parent_controller_provider.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/entity/meal.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog_result.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list_today.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';

void main() {
  setUp(() => setLanguageStringsFromCode('en'));

  testWidgets(
    'rapid duplicate skip confirmation produces one persistence result',
    (tester) async {
      late final ForegroundUiHarness harness;
      late final int id;
      late final DateTime plannedAt;
      var handledResults = 0;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        plannedAt = DateTime.now().add(const Duration(minutes: 30));
        id = await _insertPlannedMeal(
          harness,
          'Duplicate confirmation integration',
          plannedAt: plannedAt,
        );
        harness.startMonitoring();
      });
      addTearDown(harness.close);

      await _waitForMealMonitor(tester, harness);
      final meal = domain.Meal(
        id: id,
        name: 'Duplicate confirmation integration',
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
                    final result = await showDialog<MealStatusDialogResult>(
                      context: context,
                      builder: (_) => MealStatusDialog(meal: meal),
                    );
                    if (result != null && context.mounted) {
                      handledResults++;
                      await handleMealStatusDialogResult(
                        context: context,
                        ref: ref,
                        meal: meal,
                        result: result,
                        openSummaryAfterEaten: false,
                      );
                    }
                  },
                  child: const Text('Open duplicate test meal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open duplicate test meal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await _pumpWithIo(tester);
      final confirm = find.text('Confirm');
      await tester.tap(confirm);
      await tester.tap(confirm, warnIfMissed: false);
      await _pumpWithIo(tester);
      expect(find.byType(MealStatusDialog), findsNothing);
      expect(handledResults, 1);
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 100; attempt++) {
          final row = await harness.foregroundDb.mealDao.getMealById(id);
          if (row?.status == 'skipped') return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(harness.mealStatus?.phase, MealMonitoringPhase.idle);
      await tester.runAsync(() async {
        final uiHistory = await harness.uiDb
            .select(harness.uiDb.mealStatusHistory)
            .get();
        final foregroundHistory = await harness.foregroundDb
            .select(harness.foregroundDb.mealStatusHistory)
            .get();
        expect(
          uiHistory.where(
            (entry) => entry.mealId == id && entry.status == 'skipped',
          ),
          hasLength(1),
        );
        expect(
          foregroundHistory.where(
            (entry) => entry.mealId == id && entry.status == 'skipped',
          ),
          hasLength(1),
        );
      });
    },
  );

  testWidgets(
    'starting a planned meal is blocked while another meal is active',
    (tester) async {
      late final ForegroundUiHarness harness;
      late final int activeId;
      late final int plannedId;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        activeId = await _insertPlannedMeal(
          harness,
          'Active integration',
          status: 'eating',
        );
        plannedId = await _insertPlannedMeal(
          harness,
          'Blocked integration',
          plannedAt: DateTime.now().add(const Duration(hours: 1)),
        );
      });
      addTearDown(harness.close);
      final plannedAt = DateTime.now().add(const Duration(hours: 1));
      final meal = domain.Meal(
        id: plannedId,
        name: 'Blocked integration',
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
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => MealStatusDialog(meal: meal),
                  ),
                  child: const Text('Open blocked meal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open blocked meal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I will eat'));
      await _pumpWithIo(tester);
      expect(find.textContaining('Active integration'), findsOneWidget);
      expect(find.byType(MealStatusDialog), findsOneWidget);
      await tester.runAsync(() async {
        expect(
          (await harness.uiDb.mealDao.getMealById(activeId))?.status,
          'eating',
        );
        expect(
          (await harness.uiDb.mealDao.getMealById(plannedId))?.status,
          'planned',
        );
      });
    },
  );

  testWidgets(
    'deleting the last planned meal through the production list clears monitoring',
    (tester) async {
      late final ForegroundUiHarness harness;
      late final int id;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          uiOverrides: [parentModeProvider.overrideWithValue(true)],
        );
        id = await _insertPlannedMeal(harness, 'Delete last integration');
        harness.startMonitoring();
      });
      addTearDown(harness.close);
      await _waitForMealMonitor(tester, harness);
      expect(harness.mealStatus?.mealId, id);
      await _mountTodayList(tester, harness);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete meal'));
      await _pumpWithIo(tester);
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          if (await harness.uiDb.mealDao.getMealById(id) == null) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(
        await tester.runAsync(() => harness.uiDb.mealDao.getMealById(id)),
        isNull,
      );
      await _waitForMonitoringUpdate(
        tester,
        () => harness.mealStatus?.phase == MealMonitoringPhase.idle,
      );
      expect(harness.mealStatus?.phase, MealMonitoringPhase.idle);
    },
    // Regression: NextMealCollector does not publish removal of the last planned meal.
  );

  testWidgets('deleting one planned meal selects the replacement monitor', (
    tester,
  ) async {
    late final ForegroundUiHarness harness;
    late final int firstId;
    late final int replacementId;
    await tester.runAsync(() async {
      harness = await ForegroundUiHarness.create(
        uiOverrides: [parentModeProvider.overrideWithValue(true)],
      );
      firstId = await _insertPlannedMeal(harness, 'Delete first integration');
      replacementId = await _insertPlannedMeal(
        harness,
        'Replacement integration',
        plannedAt: DateTime.now().add(const Duration(hours: 2)),
      );
      harness.startMonitoring();
    });
    addTearDown(harness.close);
    await _waitForMealMonitor(tester, harness);
    expect(harness.mealStatus?.mealId, firstId);
    await _mountTodayList(tester, harness);
    expect(harness.uiContainer.read(parentModeProvider), isTrue);
    expect(find.text('Delete first integration'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete meal'));
    await _pumpWithIo(tester);
    await _waitForMonitoringUpdate(
      tester,
      () => harness.mealStatus?.mealId == replacementId,
    );
    expect(
      await tester.runAsync(() => harness.uiDb.mealDao.getMealById(firstId)),
      isNull,
    );
    expect(harness.mealStatus?.mealId, replacementId);
  });

  testWidgets('planned meal is displayed and monitored by foreground', (
    tester,
  ) async {
    late final ForegroundUiHarness harness;
    late final int id;
    late final DateTime plannedAt;
    await tester.runAsync(() async {
      harness = await ForegroundUiHarness.create();
      plannedAt = DateTime.now().add(const Duration(minutes: 30));
      id = await _insertPlannedMeal(
        harness,
        'Lunch integration',
        plannedAt: plannedAt,
      );
      harness.startMonitoring();
    });
    addTearDown(harness.close);

    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        if (harness.mealStatus?.mealId != null) return;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(harness.mealStatus?.mealId, id);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.uiContainer,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: MealListToday()),
        ),
      ),
    );
    await _pumpWithIo(tester);
    expect(find.text('Lunch integration'), findsOneWidget);
  });

  testWidgets(
    'canceling the production skip confirmation preserves UI and monitor state',
    (tester) async {
      late final ForegroundUiHarness harness;
      late final int id;
      late final DateTime plannedAt;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        plannedAt = DateTime.now().add(const Duration(minutes: 30));
        id = await _insertPlannedMeal(
          harness,
          'Cancel integration',
          plannedAt: plannedAt,
        );
        harness.startMonitoring();
      });
      addTearDown(harness.close);
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          if (harness.mealStatus?.mealId != null) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(harness.mealStatus?.mealId, id);
      final meal = domain.Meal(
        id: id,
        name: 'Cancel integration',
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
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => MealStatusDialog(meal: meal),
                  ),
                  child: const Text('Open meal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open meal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await _pumpWithIo(tester);
      expect(find.text('Confirm meal skip'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect((await harness.uiDb.mealDao.getMealById(id))?.status, 'planned');
        expect(
          (await harness.foregroundDb.mealDao.getMealById(id))?.status,
          'planned',
        );
      });
      expect(harness.mealStatus?.mealId, id);
    },
  );

  testWidgets(
    'skip confirmation persists through the production dialog and stops monitoring',
    (tester) async {
      late final ForegroundUiHarness harness;
      late final int id;
      late final DateTime plannedAt;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create();
        plannedAt = DateTime.now().add(const Duration(minutes: 30));
        id = await _insertPlannedMeal(
          harness,
          'Skip integration',
          plannedAt: plannedAt,
        );
        harness.startMonitoring();
      });
      addTearDown(harness.close);
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          if (harness.mealStatus?.mealId != null) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(harness.mealStatus?.mealId, id);

      final meal = domain.Meal(
        id: id,
        name: 'Skip integration',
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
                    final result = await showDialog<MealStatusDialogResult>(
                      context: context,
                      builder: (_) => MealStatusDialog(meal: meal),
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
                  },
                  child: const Text('Open meal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open meal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await _pumpWithIo(tester);
      await tester.tap(find.text('Confirm'));
      await _pumpWithIo(tester);
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          final persisted = await harness.foregroundDb.mealDao.getMealById(id);
          if (persisted?.status == 'skipped') return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(
        (await tester.runAsync(
          () => harness.uiDb.mealDao.getMealById(id),
        ))?.status,
        'skipped',
      );
      await tester.runAsync(() async {
        final uiHistory = await harness.uiDb
            .select(harness.uiDb.mealStatusHistory)
            .get();
        final foregroundHistory = await harness.foregroundDb
            .select(harness.foregroundDb.mealStatusHistory)
            .get();
        expect(
          uiHistory.where(
            (entry) => entry.mealId == id && entry.status == 'skipped',
          ),
          hasLength(1),
        );
        expect(
          foregroundHistory.where(
            (entry) => entry.mealId == id && entry.status == 'skipped',
          ),
          hasLength(1),
        );
      });
      expect(harness.mealStatus?.phase, MealMonitoringPhase.idle);
    },
  );
}

Future<int> _insertPlannedMeal(
  ForegroundUiHarness harness,
  String name, {
  DateTime? plannedAt,
  String status = 'planned',
}) {
  final scheduledAt =
      plannedAt ?? DateTime.now().add(const Duration(minutes: 30));
  return harness.uiDb
      .into(harness.uiDb.meal)
      .insert(
        MealCompanion.insert(
          name: name,
          plannedAt: scheduledAt.millisecondsSinceEpoch,
          status: Value(status),
        ),
      );
}

Future<void> _waitForMealMonitor(
  WidgetTester tester,
  ForegroundUiHarness harness,
) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 100; i++) {
      if (harness.mealStatus?.mealId != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  expect(harness.mealStatus?.mealId, isNotNull);
}

Future<void> _mountTodayList(
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
        home: const Scaffold(body: MealListToday()),
      ),
    ),
  );
  await _pumpWithIo(tester);
}

Future<void> _pumpWithIo(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pumpAndSettle();
}

/// DB commit and a foreground notification are separate asynchronous boundaries.
Future<void> _waitForMonitoringUpdate(
  WidgetTester tester,
  bool Function() ready,
) async {
  for (var attempt = 0; attempt < 400 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(
    ready(),
    isTrue,
    reason: 'Foreground must observe the committed meal change.',
  );
}
