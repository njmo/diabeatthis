import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_collections_body.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_plan_status_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planned_activity_card.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_occurrence_view.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_upcoming_sessions_button.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_upcoming_sessions_view.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../presentation/caregiver_audit_fixture.dart';
import '../presentation/family_collection_fixtures.dart';

Map<String, dynamic> upcomingFixture(
  int id,
  DateTime time, {
  String status = 'pending',
  int? logId,
}) => mirrorRow('activityOccurrences', id, {
  'activity_id': 5,
  'started_at': time.millisecondsSinceEpoch,
  'duration_minutes': 30,
  'status': status,
  'schedule_id': null,
  'activity_log_id': logId,
});
Map<String, dynamic> activityProposal(
  String id,
  String type,
  DateTime time, {
  String status = 'pending',
  int? targetId,
}) => {
  'id': id,
  'type': type,
  'status': status,
  'targetId': targetId,
  'createdAt': time.millisecondsSinceEpoch,
  'values': {
    'activityId': 5,
    'startedAt': time.millisecondsSinceEpoch,
    'durationMinutes': 30,
  },
  'base': [],
};

void main() {
  late CaregiverAuditFixture fixture;
  late DateTime now;
  late List<(String, int?, Map<String, dynamic>?)> edits;
  setUp(() {
    fixture = CaregiverAuditFixture();
    now = DateTime.now();
    edits = [];
  });
  tearDown(() => fixture.close());
  Future<void> mount(
    WidgetTester tester, {
    FamilyPlanningView view = FamilyPlanningView.activities,
    bool enabled = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleAccountProvider.overrideWith(
            (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
          ),
          timeNowProvider.overrideWithValue(AsyncData(now)),
          databaseProvider.overrideWith(
            (ref) => throw StateError('No caregiver patient database'),
          ),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: FamilyCollectionsBody(
              family: fixture.family,
              view: view,
              enabled: enabled,
              mealValues: (_) => {},
              edit: (type, {targetId, initial}) async {
                edits.add((type, targetId, initial));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    final context = tester.element(find.byType(FamilyCollectionsBody));
    await tester.tap(find.text(context.lang.dashboardUpcomingTitle));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'history top opens shared sessions and preserves confirm/move without child-only controls',
    (tester) async {
      final start = now.add(const Duration(hours: 2));
      fixture.family.rows['activityOccurrences/9'] = upcomingFixture(9, start);
      await mount(tester);
      expect(find.byType(ActivityUpcomingSessionsButton), findsOneWidget);
      expect(find.byType(FamilyPlannedActivityCard), findsNothing);
      await open(tester);
      expect(find.byType(ActivityUpcomingSessionsView), findsOneWidget);
      final context = tester.element(find.byType(ActivityOccurrenceView));
      await tester.tap(find.text(context.lang.activityScheduleYes));
      await tester.tap(find.text(context.lang.activityScheduleMove));
      expect(edits, hasLength(2));
      expect(edits[0], ('confirmActivity', 9, null));
      expect(edits[1].$1, 'moveActivity');
      expect(edits[1].$2, 9);
      expect(edits[1].$3, {'startedAt': start.millisecondsSinceEpoch});
      final card = tester.widget<ActivityOccurrenceView>(
        find.byType(ActivityOccurrenceView),
      );
      expect(card.onDelete, isNull);
      expect(card.onSkip, isNotNull);
      expect(card.onHistory, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'loading recovery updates open actions and stale scope or monitoring blocks old callbacks',
    (tester) async {
      fixture.family.rows['activityOccurrences/9'] = upcomingFixture(
        9,
        now.add(const Duration(hours: 2)),
      );
      fixture.family.complete = false;
      await mount(tester, enabled: false);
      await open(tester);
      expect(
        tester
            .widget<FamilyPlannedActivityCard>(
              find.byType(FamilyPlannedActivityCard),
            )
            .onConfirm,
        isNull,
      );
      fixture.family.complete = true;
      fixture.family.notifyListeners();
      await tester.pumpAndSettle();
      final oldConfirm = tester
          .widget<FamilyPlannedActivityCard>(
            find.byType(FamilyPlannedActivityCard),
          )
          .onConfirm!;
      (fixture.family.rows['activityOccurrences/9']!['payload']
              as Map)['target_requested_at'] =
          now.millisecondsSinceEpoch;
      oldConfirm();
      expect(edits, hasLength(1));
      edits.clear();
      (fixture.family.rows['activityOccurrences/9']!['payload']
          as Map)['started_at'] = now
          .add(const Duration(minutes: 30))
          .millisecondsSinceEpoch;
      oldConfirm();
      expect(edits, isEmpty);
      (fixture.family.rows['activityOccurrences/9']!['payload']
          as Map)['started_at'] = now
          .add(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      (fixture.family.rows['activityOccurrences/9']!['payload']
              as Map)['target_requested_at'] =
          null;
      fixture.family.source = 'other-family';
      oldConfirm();
      expect(edits, isEmpty);
      fixture.family.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(ActivityOccurrenceView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'upcoming window matches child and excludes recorded sessions even during partial mirror updates',
    (tester) async {
      for (final row in [
        upcomingFixture(9, now.add(const Duration(hours: 2))),
        upcomingFixture(
          10,
          now.subtract(const Duration(hours: 2)),
          status: 'missed',
        ),
        upcomingFixture(
          11,
          now.subtract(const Duration(days: 8)),
          status: 'missed',
        ),
        upcomingFixture(
          12,
          now.add(const Duration(hours: 3)),
          status: 'recorded',
        ),
        upcomingFixture(13, now.add(const Duration(hours: 4)), logId: 6),
      ]) {
        fixture.family.rows['activityOccurrences/${row['id']}'] = row;
      }
      await mount(tester);
      await open(tester);
      expect(
        tester
            .widget<ActivityUpcomingSessionsView>(
              find.byType(ActivityUpcomingSessionsView),
            )
            .entries,
        hasLength(2),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'history contains execution proposals instead of daily future plans',
    (tester) async {
      fixture.family.rows['activityOccurrences/9'] = upcomingFixture(
        9,
        now.add(const Duration(hours: 2)),
      );
      fixture.family.plans = [
        activityProposal(
          'future',
          'planActivity',
          now.add(const Duration(hours: 3)),
        ),
        activityProposal('start', 'startActivity', now),
      ];
      await mount(tester, view: FamilyPlanningView.activities);
      expect(find.byType(FamilyPlannedActivityCard), findsNothing);
      expect(
        tester
            .widget<FamilyPlanStatusCard>(find.byType(FamilyPlanStatusCard))
            .plan['type'],
        'startActivity',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'new plan stays visible until mirrored without duplicate result card',
    (tester) async {
      fixture.family.plans = [
        activityProposal(
          'future',
          'planActivity',
          now.add(const Duration(hours: 2)),
        ),
      ];
      await mount(tester);
      await open(tester);
      expect(find.byType(FamilyPlanStatusCard), findsOneWidget);
      fixture.family.rows['activityOccurrences/9'] = upcomingFixture(
        9,
        now.add(const Duration(hours: 2)),
      );
      fixture.family.plans.single['status'] = 'applied';
      fixture.family.plans.single['resultId'] = 9;
      fixture.family.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(FamilyPlanStatusCard), findsNothing);
      expect(find.byType(FamilyPlannedActivityCard), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final targeted in [false, true]) {
    testWidgets(
      'retry rechecks proposal status before reopening: targeted=$targeted',
      (tester) async {
        if (targeted) {
          fixture.family.rows['activityOccurrences/9'] = upcomingFixture(
            9,
            now.add(const Duration(hours: 2)),
          );
        }
        fixture.family.plans = [
          activityProposal(
            'rejected',
            targeted ? 'moveActivity' : 'planActivity',
            now.add(const Duration(hours: 3)),
            status: 'rejected',
            targetId: targeted ? 9 : null,
          ),
        ];
        await mount(tester);
        await open(tester);
        final callback = targeted
            ? tester
                  .widget<FamilyPlannedActivityCard>(
                    find.byType(FamilyPlannedActivityCard),
                  )
                  .onRetry!
            : tester
                  .widget<FamilyPlanStatusCard>(
                    find.byType(FamilyPlanStatusCard),
                  )
                  .onRetry!;
        fixture.family.plans.single['status'] = 'applied';
        callback();
        expect(edits, isEmpty);
        fixture.family.plans.single['status'] = 'rejected';
        callback();
        expect(edits.single.$1, targeted ? 'moveActivity' : 'planActivity');
        expect(edits.single.$2, targeted ? 9 : null);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
