import 'dart:async';

import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planned_activity_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planning_page.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_refresh_state.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_visible_state_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_card.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_target_card.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_completed_activity_card.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_target_actions.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_target_progress.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'caregiver links a mirrored activity to the live target without local actions',
    (tester) async {
      final start = DateTime(2026, 11, 8, 12);
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final time = StreamController<DateTime>();
      addTearDown(time.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            googleAccountProvider.overrideWith((_) => Stream.value(null)),
            timeNowProvider.overrideWith((_) => time.stream),
            caregiverVisibleStateProvider.overrideWithValue(
              CaregiverRefreshState(
                snapshot: CaregiverNightscoutSnapshot(
                  targetFetched: true,
                  hasFailures: false,
                  temporaryTarget: TemporaryTarget(
                    nightscoutId: 'target',
                    createdAt: start,
                    duration: 30,
                    durationInMiliseconds: 1800000,
                    targetBottom: 135,
                    targetTop: 140,
                  ),
                ),
              ),
            ),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(
              body: FamilyPlanningPage(
                embedded: true,
                view: FamilyPlanningView.home,
              ),
            ),
          ),
        ),
      );
      time.add(start.add(const Duration(minutes: 10)));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardActivityTargetCard), findsOneWidget);
      final lang = tester.element(find.byType(FamilyPlanningPage)).lang;
      final range = find.text(lang.caregiverTargetRange('135', '140'));
      expect(range, findsOneWidget);
      final page = tester.state<FamilyPlanningPageState>(
        find.byType(FamilyPlanningPage),
      );
      page.controller.source = 'mirror';
      final activityStart = start.add(const Duration(minutes: 11));
      page.controller.rows.addAll({
        'activities/1': {
          'kind': 'activities',
          'id': '1',
          'payload': {'id': 1, 'name': 'PE', 'duration_minutes': 30},
        },
        'activityLogs/1': {
          'kind': 'activityLogs',
          'id': '1',
          'payload': {
            'id': 1,
            'activity_id': 1,
            'started_at': activityStart.millisecondsSinceEpoch,
          },
        },
        'activityOccurrences/1': {
          'kind': 'activityOccurrences',
          'id': '1',
          'payload': {
            'id': 1,
            'activity_id': 1,
            'activity_log_id': 1,
            'status': 'planned',
            'started_at': activityStart.millisecondsSinceEpoch,
            'duration_minutes': null,
          },
        },
      });
      page.changed();
      await tester.pumpAndSettle();
      final activityCard = find.byType(DashboardActivityCard);
      final progress = find.descendant(
        of: activityCard,
        matching: find.byType(DashboardTargetProgress),
      );
      expect(activityCard, findsOneWidget);
      expect(
        tester
            .widget<DashboardActivityCard>(activityCard)
            .activity
            .durationMinutes,
        isNull,
      );
      expect(find.byType(DashboardActivityTargetCard), findsNothing);
      expect(progress, findsOneWidget);
      expect(range, findsOneWidget);
      expect(find.byType(FamilyPlannedActivityCard), findsNothing);
      expect(find.text(lang.dashboardPlannedActivityTitle), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(1 / 3, .001),
      );
      expect(find.byType(DashboardTargetActions), findsNothing);
      final request = <String, dynamic>{
        'type': 'moveActivity',
        'targetId': 1,
        'status': 'pending',
      };
      page.controller.plans = [request];
      page.changed();
      await tester.pumpAndSettle();
      expect(find.text(lang.familyWaitingForAcceptance), findsOneWidget);
      expect(find.text(lang.dashboardPlannedActivityTitle), findsOneWidget);
      request['status'] = 'rejected';
      page.changed();
      await tester.pumpAndSettle();
      expect(find.text(lang.familyPlanRejected), findsOneWidget);
      page.controller.plans = [];
      page.changed();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(
        find.text(lang.dashboardActivityInProgressCardTitle),
        findsOneWidget,
      );
      expect(
        find.text(lang.dashboardActivityOngoingTarget(140)),
        findsOneWidget,
      );
      time.add(start.add(const Duration(minutes: 20)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(2 / 3, .001),
      );
      final log = page.controller.rows['activityLogs/1']!['payload'] as Map;
      log['ended_at'] = start
          .add(const Duration(minutes: 19))
          .millisecondsSinceEpoch;
      page.changed();
      await tester.pumpAndSettle();
      expect(activityCard, findsNothing);
      expect(
        find.descendant(
          of: find.byType(DashboardCompletedActivityCard),
          matching: find.byType(DashboardTargetProgress),
        ),
        findsOneWidget,
      );
      expect(find.byType(DashboardTargetActions), findsNothing);
      time.add(start.add(const Duration(minutes: 30)));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardTargetProgress), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
