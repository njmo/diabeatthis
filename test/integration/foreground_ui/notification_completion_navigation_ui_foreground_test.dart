import 'package:clock/clock.dart';
import 'package:diabeatthis/app/router/providers/app_router_provider.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/pending_meal_completion_requests.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_eating_finish_time_step.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_entry.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_task_event_test_host.dart';
import '../../helpers/foreground_ui/foreground_to_ui_test_router.dart';
import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/foreground_ui/notification_response_wire.dart';
import '../../helpers/foreground_ui/pump_database_streams.dart';
import '../../helpers/foreground_ui/recording_navigator_observer.dart';

void main() {
  testWidgets(
    'late Agree opens the real completion sheet and cancel preserves meal',
    (tester) async {
      final now = DateTime.now();
      late ForegroundUiHarness harness;
      late ForegroundToUiTestRouter transport;
      late int mealId;
      await tester.runAsync(() async {
        transport = ForegroundToUiTestRouter();
        harness = await _createHarness(transport);
        mealId = await _seedLateEatingMeal(harness.uiDb, now);
      });
      try {
        await _mount(tester, harness, transport);
        await tester.runAsync(
          () => withClock(Clock.fixed(now), () async {
            ExternalEventHandler(
              harness.runtimeContext,
            ).handle(_notificationWire(mealId));
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }),
        );

        await _pumpUntilEntry(tester, mealId);
        final beforeCancel = await tester.runAsync(
          () => _mealState(harness.uiDb, mealId),
        );
        _expectUnchangedEatingMeal(beforeCancel!);
        expect(transport.messages, hasLength(1));
        expect(transport.messages.single, {
          'event': 'task_open_meal_completion',
          'data': {'mealId': mealId},
        });

        // The production bottom sheet occupies the lower 80% of the screen;
        // tapping the barrier above it is the actual cancel gesture.
        await tester.tapAt(const Offset(10, 10));
        await _pumpUntilEntryGone(tester);
        final afterCancel = await tester.runAsync(
          () => _mealState(harness.uiDb, mealId),
        );
        _expectUnchangedEatingMeal(afterCancel!);
        final pending = await tester.runAsync(
          () => harness.uiContainer
              .read(pendingMealCompletionRequestsProvider)
              .pending(),
        );
        expect(pending, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(harness.close);
      }
    },
  );

  for (final repeatWhileClosing in [false, true]) {
    testWidgets(
      'pending late Agree recovery opens once and remains dismissed; repeated recovery=$repeatWhileClosing',
      (tester) async {
        final navigation = RecordingNavigatorObserver();
        final now = DateTime.now();
        late ForegroundUiHarness harness;
        late ForegroundToUiTestRouter transport;
        late int mealId;
        await tester.runAsync(() async {
          transport = ForegroundToUiTestRouter();
          harness = await _createHarness(transport);
          mealId = await _seedLateEatingMeal(harness.uiDb, now);
        });
        try {
          await tester.runAsync(
            () => withClock(Clock.fixed(now), () async {
              ExternalEventHandler(
                harness.runtimeContext,
              ).handle(_notificationWire(mealId));
              await Future<void>.delayed(const Duration(milliseconds: 30));
            }),
          );
          expect(transport.messages, hasLength(1));
          final pendingBeforeMount = await tester.runAsync(
            () => harness.uiContainer
                .read(pendingMealCompletionRequestsProvider)
                .pending(),
          );
          expect(pendingBeforeMount, {mealId});

          await _mount(tester, harness, transport, observer: navigation);
          _uiHandler(tester).handler.retryPendingUiActions();
          await _pumpUntilEntry(tester, mealId);
          if (repeatWhileClosing) {
            _uiHandler(tester).handler.retryPendingUiActions();
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.byType(MealCompletionEntry), findsOneWidget);
          expect(
            tester
                .widget<MealCompletionEntry>(find.byType(MealCompletionEntry))
                .mealId,
            mealId,
          );

          await tester.tapAt(const Offset(10, 10));
          await pumpDatabaseStreams(tester);
          expect(
            (
              navigation.pushed
                  .whereType<ModalBottomSheetRoute<dynamic>>()
                  .length,
              navigation.popped
                  .whereType<ModalBottomSheetRoute<dynamic>>()
                  .length,
            ),
            (1, 1),
            reason:
                'Recovery must not reopen an acknowledged, dismissed sheet.',
          );
          await _pumpUntilEntryGone(tester);
          final pendingAfterCancel = await tester.runAsync(
            () => harness.uiContainer
                .read(pendingMealCompletionRequestsProvider)
                .pending(),
          );
          expect(pendingAfterCancel, isEmpty);
          final afterCancel = await tester.runAsync(
            () => _mealState(harness.uiDb, mealId),
          );
          _expectUnchangedEatingMeal(afterCancel!);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(harness.close);
        }
      },
      // Regression: an in-flight recovery may replay a sheet after cancellation
      // has already acknowledged the durable intent. Normal recovery stays enabled.
    );
  }
}

Future<ForegroundUiHarness> _createHarness(
  ForegroundToUiTestRouter transport,
) => ForegroundUiHarness.create(
  foregroundOverrides: [taskEventRouterProvider.overrideWithValue(transport)],
);

Future<void> _mount(
  WidgetTester tester,
  ForegroundUiHarness harness,
  ForegroundToUiTestRouter transport, {
  NavigatorObserver? observer,
}) => tester.pumpWidget(
  UncontrolledProviderScope(
    container: harness.uiContainer,
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        navigatorKey: ref.watch(appRouterProvider).navigatorKey,
        navigatorObservers: [if (observer != null) observer],
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ForegroundTaskEventTestHost(
          transport: transport,
          child: const Scaffold(body: Text('Test application')),
        ),
      ),
    ),
  ),
);

ForegroundTaskEventTestHostState _uiHandler(WidgetTester tester) =>
    tester.state<ForegroundTaskEventTestHostState>(
      find.byType(ForegroundTaskEventTestHost),
    );

Future<void> _pumpUntilEntry(WidgetTester tester, int mealId) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    final entries = find.byType(MealCompletionEntry);
    if (entries.evaluate().isNotEmpty &&
        find.byType(MealEatingFinishTimeStep).evaluate().isNotEmpty) {
      expect(tester.widget<MealCompletionEntry>(entries).mealId, mealId);
      return;
    }
  }
  expect(find.byType(MealCompletionEntry), findsOneWidget);
  expect(find.byType(MealEatingFinishTimeStep), findsOneWidget);
}

Future<void> _pumpUntilEntryGone(WidgetTester tester) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (find.byType(MealCompletionEntry).evaluate().isEmpty) return;
  }
  expect(find.byType(MealCompletionEntry), findsNothing);
}

Future<int> _seedLateEatingMeal(DatabaseImpl db, DateTime now) async {
  final startedAt = now.subtract(const Duration(hours: 5));
  final ingredientId = await db
      .into(db.ingredient)
      .insert(
        IngredientCompanion.insert(
          name: 'Navigation test rice',
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
          name: 'Late navigation meal',
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

Map<String, dynamic> _notificationWire(int mealId) => notificationResponseWire(
  FinishedEatingNotificationEvent(mealId: mealId),
  'agree',
);

Future<({String? status, double? amount, List<String> history})> _mealState(
  DatabaseImpl db,
  int mealId,
) async {
  final meal = await db.mealDao.getMealById(mealId);
  final ingredient = await db.mealIngredientsDao.getMealIngredientsForMeal(
    mealId,
  );
  final history = await (db.select(
    db.mealStatusHistory,
  )..where((row) => row.mealId.equals(mealId))).get();
  return (
    status: meal?.status,
    amount: ingredient.single.consumedAmount,
    history: history.map((row) => row.status).toList(),
  );
}

void _expectUnchangedEatingMeal(
  ({String? status, double? amount, List<String> history}) state,
) {
  expect(state.status, 'eating');
  expect(state.amount, 100);
  expect(state.history, ['eating']);
}
