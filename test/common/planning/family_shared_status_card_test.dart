import 'package:diabeatthis/common/family_sync/presentation/family_active_meal_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_activity_log_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_plan_status_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planned_meal_card.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_progress_plan.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/meal_decision_answered_status.dart';
import 'package:diabeatthis/common/widgets/history_entry_row.dart';
import 'package:diabeatthis/common/widgets/meal_progress/meal_progress_steps.dart';
import 'package:diabeatthis/common/widgets/status_info_card.dart';
import 'package:diabeatthis/features/activity/common/controllers/activity_actions_controller.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_card.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('caregiver shows future stages from the accepted meal decision', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FamilyActiveMealCard(
            payload: const {'name': 'Lunch', 'status': 'waiting-for-bolus'},
            now: DateTime(2026, 11, 19, 12),
            decision: MealDecision.bolusWaitThenEat,
          ),
        ),
      ),
    );

    final plan = tester
        .widget<MealProgressSteps>(find.byType(MealProgressSteps))
        .plan;
    expect(plan.stages, [
      MealProgressStage.bolus,
      MealProgressStage.waiting,
      MealProgressStage.eating,
    ]);
    expect(plan.currentIndex, 0);
    expect(find.byType(FilledButton), findsNothing);
  });

  for (final (original, stages, bolusIndex) in [
    (
      'eating-then-bolus',
      [
        MealProgressStage.eating,
        MealProgressStage.bolus,
        MealProgressStage.extra,
      ],
      1,
    ),
    (
      'bolused-eating',
      [
        MealProgressStage.bolus,
        MealProgressStage.eating,
        MealProgressStage.bolus,
        MealProgressStage.extra,
      ],
      2,
    ),
    (
      'waited-eating',
      [
        MealProgressStage.bolus,
        MealProgressStage.waiting,
        MealProgressStage.eating,
        MealProgressStage.bolus,
        MealProgressStage.extra,
      ],
      3,
    ),
  ]) {
    for (final awaiting in [true, false]) {
      testWidgets('caregiver mirrors extra for $original, awaiting=$awaiting', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyActiveMealCard(
                payload: {
                  'name': 'Lunch',
                  'status': 'eating-extra',
                  'add_on_progress':
                      '{"originalStatus":"$original","awaitingBolus":${awaiting ? 1 : 0},"additionalServing":1,"bolusBeforeExtra":1}',
                },
                now: DateTime(2026, 11, 19, 12),
                history: [original, 'eating-extra'],
              ),
            ),
          ),
        );
        final plan = tester
            .widget<MealProgressSteps>(find.byType(MealProgressSteps))
            .plan;
        expect(plan.stages, stages);
        expect(plan.currentIndex, awaiting ? bolusIndex : stages.length - 1);
        expect(plan.isComplete(bolusIndex), !awaiting);
      });
    }
  }

  for (final (original, stageCount) in [
    ('bolused-eating', 3),
    ('waited-eating', 4),
  ]) {
    testWidgets('caregiver shows extra without a second bolus for $original', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FamilyActiveMealCard(
              payload: {
                'name': 'Lunch',
                'status': 'eating-extra',
                'add_on_progress':
                    '{"originalStatus":"$original","awaitingBolus":0,"additionalServing":1,"bolusBeforeExtra":0}',
              },
              now: DateTime(2026, 11, 19, 12),
            ),
          ),
        ),
      );
      final plan = tester
          .widget<MealProgressSteps>(find.byType(MealProgressSteps))
          .plan;
      expect(plan.stages, hasLength(stageCount));
      expect(
        plan.stages.where((stage) => stage == MealProgressStage.bolus),
        hasLength(1),
      );
      expect(plan.currentIndex, stageCount - 1);
    });
  }

  for (final payload in [null, 'broken JSON']) {
    testWidgets(
      'unknown extra progress does not mark bolus completed ($payload)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyActiveMealCard(
                payload: {
                  'name': 'Lunch',
                  'status': 'eating-extra',
                  'add_on_progress': payload,
                },
                now: DateTime(2026, 11, 19, 12),
                decision: MealDecision.eatNowBolusLater,
              ),
            ),
          ),
        );
        final plan = tester
            .widget<MealProgressSteps>(find.byType(MealProgressSteps))
            .plan;
        expect(plan.stages, [MealProgressStage.extra]);
        expect(plan.currentIndex, 0);
        expect(plan.isComplete(0), isFalse);
      },
    );
  }

  testWidgets('caregiver status and retry are inside the compact meal tile', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FamilyPlannedMealCard(
            compact: true,
            payload: {
              'id': 1,
              'name': 'Lunch',
              'status': 'planned',
              'planned_at': DateTime(2026, 11, 19, 12).millisecondsSinceEpoch,
            },
            history: const [],
            locked: false,
            onOpen: () {},
            onRetry: () => retries++,
            decisionAction: const MealDecisionAnsweredStatus(isTimedOut: true),
          ),
        ),
      ),
    );

    final tile = find.byType(ListTile);
    final timeout = find.descendant(
      of: tile,
      matching: find.text('Time limit exceeded'),
    );
    expect(timeout, findsOneWidget);
    expect(tester.getRect(tile).contains(tester.getCenter(timeout)), isTrue);
    final retry = find.descendant(
      of: tile,
      matching: find.byIcon(Icons.refresh),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mirrored activity notes stay inside the history row', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 19, 12);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FamilyActivityLogCard(
              name: 'Walking',
              payload: {
                'started_at': now
                    .subtract(const Duration(minutes: 30))
                    .millisecondsSinceEpoch,
                'ended_at': now.millisecondsSinceEpoch,
                'notes': 'Park route',
              },
            ),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(HistoryEntryRow),
        matching: find.text('Park route'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'pending start uses child card without pretending monitoring started or exposing technical data',
    (tester) async {
      final plan = <String, dynamic>{
        'id': 'request',
        'type': 'startActivity',
        'status': 'pending',
        'targetId': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'base': [],
        'values': {
          'activityId': null,
          'activity': {'name': 'Walking', 'durationMinutes': 30},
          'startedAt': DateTime.now().millisecondsSinceEpoch,
        },
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityActionsControllerProvider.overrideWith(
              () => throw StateError('No child actions'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyPlanStatusCard(plan: plan, onRetry: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DashboardActivityCard), findsOneWidget);
      expect(find.byType(StatusInfoCard), findsOneWidget);
      expect(find.byType(DashboardActivityProgress), findsNothing);
      expect(find.text('Walking'), findsOneWidget);
      final language = AppLocalizations.of(
        tester.element(find.byType(FamilyPlanStatusCard)),
      );
      expect(find.text(language.familyWaitingForStart), findsOneWidget);
      expect(find.text(language.familyPlanBefore), findsNothing);
      expect(find.text(language.familyPlanProposal), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('canonical result replaces pending card without duplicate', () {
    final plan = <String, dynamic>{
      'type': 'startActivity',
      'status': 'pending',
      'targetId': null,
      'resultId': 7,
    };
    expect(showFamilyPlanStatus(plan, []), isTrue);
    expect(
      showFamilyPlanStatus(plan, [
        {'kind': 'activityLogs', 'id': '7', 'deleted': false},
      ]),
      isFalse,
    );
  });
  testWidgets(
    'mirrored running log uses the actual child dashboard card with no local actions',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityActionsControllerProvider.overrideWith(
              () => throw StateError('No child actions'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyActivityLogCard(
                name: 'Walking',
                durationMinutes: 30,
                payload: {
                  'id': 7,
                  'activity_id': 1,
                  'started_at': DateTime.now()
                      .subtract(const Duration(minutes: 2))
                      .millisecondsSinceEpoch,
                  'ended_at': null,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DashboardActivityCard), findsOneWidget);
      expect(find.byType(DashboardActivityProgress), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
