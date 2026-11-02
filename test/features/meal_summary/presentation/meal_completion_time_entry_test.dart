import 'package:clock/clock.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_completion_time_section.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_eating_finish_time_step.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_summary_page.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

class TimeEntryMealController extends MealSummaryControllerNotifier {
  TimeEntryMealController(this.status);
  final String status;

  @override
  Future<MealSummaryDraft> build(int mealId) async => MealSummaryDraft(
    mealId: mealId,
    mealStatus: status,
    itemIds: const [1],
    itemsById: const {
      1: MealSummaryItemDraft(
        name: 'Rice',
        mealIngredientId: 1,
        plannedAmount: 100,
        reportedAmount: 100,
        amountLabel: 'g',
        netCarbsPerAmount: 0.2,
        consumedAmount: 100,
        consumedConfidence: 0.8,
        gramsPerAmount: 1,
      ),
    },
    extraItems: const [],
  );
}

void main() {
  final start = DateTime(2026, 11, 1, 14, 52);
  final now = start.add(const Duration(hours: 5));
  late DatabaseImpl db;

  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> seed(
    String status, {
    DateTime? recordedEnd,
    bool missingStart = false,
  }) async {
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Lunch',
            plannedAt: start.millisecondsSinceEpoch,
            status: Value(missingStart ? status : 'planned'),
          ),
        );
    if (!missingStart) {
      final eatingStatus = status.startsWith('eaten') ? 'eating' : status;
      await db.mealDao.updateMealStatus(id, eatingStatus, occurredAt: start);
      if (recordedEnd != null) {
        await db.mealDao.updateMealStatus(id, status, occurredAt: recordedEnd);
      }
    }
    return id;
  }

  Future<void> open(
    WidgetTester tester,
    int mealId,
    String status, {
    DateTime? confirmedEnd,
    bool chooseEarlier = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mealSummaryControllerProvider.overrideWith(
            () => TimeEntryMealController(status),
          ),
        ],
        child: localizedMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MealSummaryPage(
                      mealId: mealId,
                      finishEating: true,
                      confirmedEatingEndedAt: confirmedEnd,
                      chooseEarlier: chooseEarlier,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final status in ['eating', 'eating-then-bolus', 'eating-extra']) {
    testWidgets(
      'direct $status entry asks time before quantities and back writes nothing',
      (tester) async {
        await withClock(Clock.fixed(now), () async {
          final id = await seed(status);
          final history = await db.select(db.mealStatusHistory).get();
          await open(tester, id, status);
          expect(find.byType(MealEatingFinishTimeStep), findsOneWidget);
          expect(find.byType(MealCompletionView), findsNothing);
          await tester.tap(find.text('Zjadłem teraz'));
          await tester.pumpAndSettle();
          expect(find.byType(MealEatingFinishTimeStep), findsNothing);
          expect(find.byType(MealCompletionTimeSection), findsNothing);
          expect(
            tester
                .widget<MealCompletionView>(find.byType(MealCompletionView))
                .confirmedEatingEndedAt,
            now,
          );
          expect((await db.mealDao.getMealById(id))!.status, status);
          expect(await db.select(db.mealStatusHistory).get(), history);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.text('Open'), findsOneWidget);
          expect((await db.mealDao.getMealById(id))!.status, status);
          expect(await db.select(db.mealStatusHistory).get(), history);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      },
    );
  }

  testWidgets(
    'earlier entry opens duration immediately and carries historical end without writing',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final id = await seed('eating-then-bolus');
        final history = await db.select(db.mealStatusHistory).get();
        await open(tester, id, 'eating-then-bolus', chooseEarlier: true);
        final duration = find.widgetWithText(
          TextField,
          'Ile trwało jedzenie? (min)',
        );
        expect(duration, findsOneWidget);
        await tester.enterText(duration, '15');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dalej do podsumowania'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MealCompletionView>(find.byType(MealCompletionView))
              .confirmedEatingEndedAt,
          start.add(const Duration(minutes: 15)),
        );
        expect(find.byType(MealCompletionTimeSection), findsNothing);
        expect(await db.select(db.mealStatusHistory).get(), history);
        expect((await db.mealDao.getMealById(id))!.status, 'eating-then-bolus');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets('valid explicit now entry skips the time question', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      final id = await seed('eating');
      await open(tester, id, 'eating', confirmedEnd: now);
      expect(find.byType(MealEatingFinishTimeStep), findsNothing);
      expect(find.byType(MealCompletionView), findsOneWidget);
      expect((await db.mealDao.getMealById(id))!.status, 'eating');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets(
    'unconfirmed future route timestamp cannot bypass the time question',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final id = await seed('eating');
        await open(
          tester,
          id,
          'eating',
          confirmedEnd: now.add(const Duration(minutes: 1)),
        );
        expect(find.byType(MealEatingFinishTimeStep), findsOneWidget);
        expect(find.byType(MealCompletionView), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  for (final minutes in [20, 300]) {
    testWidgets(
      'recorded $minutes minute completion is trusted only when timing is credible',
      (tester) async {
        await withClock(Clock.fixed(now), () async {
          final end = start.add(Duration(minutes: minutes));
          final id = await seed('eaten', recordedEnd: end);
          await open(tester, id, 'eaten');
          expect(
            find.byType(MealEatingFinishTimeStep),
            minutes == 20 ? findsNothing : findsOneWidget,
          );
          expect(
            find.byType(MealCompletionView),
            minutes == 20 ? findsOneWidget : findsNothing,
          );
          if (minutes == 20) {
            expect(
              tester
                  .widget<MealCompletionView>(find.byType(MealCompletionView))
                  .confirmedEatingEndedAt,
              end,
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      },
    );
  }

  testWidgets(
    'missing start and interrupted meals never silently enter quantity completion',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final id = await seed('eaten', missingStart: true);
        await open(tester, id, 'eaten');
        expect(find.byType(MealEatingFinishTimeStep), findsOneWidget);
        expect(find.byType(MealCompletionView), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await db.mealDao.updateMealStatus(id, 'interrupted');
        await open(tester, id, 'interrupted', confirmedEnd: now);
        expect(find.byType(MealEatingFinishTimeStep), findsNothing);
        expect(find.byType(MealCompletionView), findsNothing);
        expect((await db.mealDao.getMealById(id))!.status, 'interrupted');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );
}
