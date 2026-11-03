import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/features/activity/common/widgets/activity_start_time_field.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/domain/model/activity.dart';
import 'package:diabeatthis/core/domain/model/activity_log.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_log_draft.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/temporary_target_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final earlier in [false, true]) {
    testWidgets('attachment confirms ${earlier ? 'chosen earlier time' : 'now'} and reveals the linked activity', (tester) async {
      var now = DateTime(2026, 11, 3, 9, 30);
      ActivityLogDraft? saved;
      ActivityLogSummaryData? pending;
      final updates = StreamController<ActivityLogSummaryData?>.broadcast();
      addTearDown(updates.close);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((_) async => prefs),
            getPendingActivityProvider.overrideWith((_) async* {
              yield pending;
              yield* updates.stream;
            }),
            activitiesByQueryProvider('').overrideWithValue(const AsyncData([
              Activity(id: 7, name: 'Basen', percentagePre: 80, percentagePost: 120, durationMinutes: 45),
            ])),
            insertActivityLogProvider.overrideWith((ref, draft) async {
              saved = draft;
              pending = ActivityLogSummaryData(id: 42, activityId: 7, activityName: 'Basen',
                startedAt: draft.startedAt, endedAt: null, durationMinutes: 45);
              updates.add(pending);
              return ActivityLog(id: 42, activityId: 7, startedAt: draft.startedAt, endedAt: null);
            }),
            timeNowProvider.overrideWith((_) => Stream.value(now)),
          ],
          child: localizedMaterialApp(home: const Scaffold(body: SingleChildScrollView(child: DashboardStatusCard()))),
        ));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(tester.element(find.byType(DashboardStatusCard)));
        final targetStart = now.subtract(const Duration(minutes: 70));
        container.read(temporaryTargetUiProvider.notifier).update(TemporaryTarget(
          nightscoutId: 'old-target', createdAt: targetStart, durationInMiliseconds: 10800000,
          duration: 180, targetBottom: 140, targetTop: 140,
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Podepnij aktywność'));
        await tester.pumpAndSettle();
        expect(find.text('Teraz'), findsOneWidget);
        await tester.tap(find.text('Basen'));
        await tester.pumpAndSettle();
        final explicitStart = now.subtract(const Duration(minutes: 10));
        if (earlier) {
          tester.widget<ActivityStartTimeField>(find.byType(ActivityStartTimeField)).onChanged(explicitStart);
          await tester.pumpAndSettle();
        }
        now = now.add(const Duration(minutes: 3));
        await tester.ensureVisible(find.text('Wybierz'));
        await tester.tap(find.text('Wybierz'));
        await tester.pumpAndSettle();
        expect(saved, isNotNull);
        expect(saved!.startedAt, earlier ? explicitStart : now);
        expect(saved!.startedAt, isNot(targetStart));
        expect(find.text('Basen'), findsOneWidget);
        expect(find.text('Temp target aktywności: 140 mg/dl'), findsOneWidget);
        expect(find.byTooltip('Podepnij aktywność'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
