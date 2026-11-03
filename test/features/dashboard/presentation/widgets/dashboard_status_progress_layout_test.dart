import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/dashboard/common/widgets/status_time_progress.dart';
import 'package:diabeatthis/features/dashboard/data/providers/temporary_target_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  final now = DateTime(2026, 11, 3, 8);
  for (final scenario in ['running', 'planned', 'no duration', 'linked']) {
    testWidgets('$scenario activity fits a narrow screen with large text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({nightscoutUrlKey: 'https://example.com'});
      final prefs = await SharedPreferences.getInstance();
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((_) async => prefs),
            getPendingActivityProvider.overrideWithValue(AsyncData(ActivityLogSummaryData(
              id: 1, activityId: 1,
              activityName: 'Długi spacer po parku',
              startedAt: scenario == 'planned'
                  ? now.add(const Duration(minutes: 25))
                  : now.subtract(const Duration(minutes: 10)),
              endedAt: null,
              durationMinutes: scenario == 'no duration' ? null : 45,
            ))),
            timeNowProvider.overrideWithValue(AsyncData(now)),
          ],
          child: localizedMaterialApp(home: Scaffold(body: Builder(builder: (context) =>
            MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: const SingleChildScrollView(child: DashboardStatusCard()),
            ),
          ))),
        ));
        if (scenario == 'linked') {
          final container = ProviderScope.containerOf(tester.element(find.byType(DashboardStatusCard)));
          container.read(temporaryTargetUiProvider.notifier).update(TemporaryTarget(
            nightscoutId: 'activity-target', createdAt: now.subtract(const Duration(minutes: 10)),
            durationInMiliseconds: 5400000, duration: 90, targetBottom: 140, targetTop: 140,
          ));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(StatusTimeProgress), scenario == 'planned' || scenario == 'no duration'
            ? findsNothing : scenario == 'linked' ? findsNWidgets(2) : findsOneWidget);
        expect(find.byIcon(Icons.stop_circle_outlined), scenario == 'planned' ? findsNothing : findsOneWidget);
      });
    });
  }
}
