import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show DatabaseImpl, ActivityCompanion, ActivityLogCompanion;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_summary_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/temporary_target_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/controllers/dashboard_status_controller.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_status_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'summary removes the activity card while keeping its data and the active target',
    (tester) async {
      final now = DateTime.now();
      final start = now.subtract(const Duration(minutes: 30));
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.activityDao.insertActivity(
        ActivityCompanion.insert(
          name: 'Running',
          percentagePre: 80,
          percentagePost: 80,
        ),
      );
      await db.activityDao.insertActivityLog(
        ActivityLogCompanion.insert(
          activityId: 1,
          startedAt: start.millisecondsSinceEpoch,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          timeNowProvider.overrideWithValue(AsyncData(now)),
          dashboardTargetControlEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final target = TemporaryTarget(
        nightscoutId: 'activity',
        createdAt: start,
        durationInMiliseconds: 3600000,
        duration: 60,
        targetBottom: 140,
        targetTop: 140,
      );
      container.read(temporaryTargetUiProvider.notifier).update(target);
      final pendingSubscription = container.listen(
        getPendingActivityProvider,
        (_, _) {},
      );
      final completedSubscription = container.listen(
        completedActivitySummariesProvider,
        (_, _) {},
      );
      addTearDown(pendingSubscription.close);
      addTearDown(completedSubscription.close);
      await container.read(getPendingActivityProvider.future);
      await container.read(completedActivitySummariesProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(child: DashboardStatusCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lang = lookupAppLocalizations(const Locale('pl'));
      expect(find.text(lang.activitySummaryReady), findsNothing);
      await tester.runAsync(
        () => db.activityDao.finishActivityLogIfOpen(1, start, now),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.text(lang.activitySummaryReady), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.byTooltip(lang.activitySummarySkip), findsNothing);
      await tester.tap(find.text(lang.activitySummaryAction));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang.activityIntensityHigh).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A tough workout');
      await tester.tap(find.text(lang.settingsSave));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.text(lang.activitySummaryCompleted), findsNothing);
      expect(find.text('Running'), findsNothing);
      expect(find.text(lang.activitySummaryAction), findsNothing);
      expect(find.text(lang.activitySummaryEdit), findsNothing);
      expect(find.byTooltip(lang.dashboardAttachActivity), findsOneWidget);
      expect(container.read(temporaryTargetUiProvider), target);
      expect(find.byIcon(Icons.track_changes_rounded), findsOneWidget);
      final savedLog = await db.activityDao.getActivityLogById(1);
      expect(savedLog.intensity, 'high');
      expect(savedLog.notes, 'A tough workout');
      expect(savedLog.summarizedAt, isNotNull);
      container.read(temporaryTargetUiProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(find.text('Running'), findsNothing);
      expect(find.byIcon(Icons.track_changes_rounded), findsNothing);
    },
  );
}
