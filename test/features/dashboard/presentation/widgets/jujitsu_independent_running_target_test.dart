import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/widgets/status_info_card.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
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
  final start = DateTime(2026, 10, 29, 17);

  Future<ProviderContainer> show(
    WidgetTester tester, {
    required DateTime now,
    required DateTime runningTargetStart,
    required int runningTargetMinutes,
    Stream<DateTime>? ticks,
  }) async {
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((_) async => prefs),
        getPendingActivityProvider.overrideWithValue(
          AsyncData(
            ActivityLogSummaryData(
              id: 42,
              activityName: 'Jujitsu',
              activityId: 7,
              startedAt: start,
              endedAt: null,
              durationMinutes: 60,
            ),
          ),
        ),
        if (ticks == null)
          timeNowProvider.overrideWithValue(AsyncData(now))
        else
          timeNowProvider.overrideWith((_) => ticks),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(temporaryTargetUiProvider.notifier)
        .update(
          TemporaryTarget(
            nightscoutId: 'independent-running-target',
            createdAt: runningTargetStart,
            durationInMiliseconds: Duration(
              minutes: runningTargetMinutes,
            ).inMilliseconds,
            duration: runningTargetMinutes,
            targetBottom: 140,
            targetTop: 140,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: const Scaffold(body: DashboardStatusCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'running target set at thirteen is independent from jujitsu planned for seventeen',
    (tester) async {
      final now = DateTime(2026, 10, 29, 13);
      await withClock(Clock.fixed(now), () async {
        await show(
          tester,
          now: now,
          runningTargetStart: now,
          runningTargetMinutes: 90,
        );
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(find.text('Temp target aktywności'), findsOneWidget);
        expect(find.textContaining('Jujitsu'), findsNothing);
        expect(find.textContaining('Przygotowanie:'), findsNothing);
      });
    },
  );

  testWidgets(
    'revealing planned jujitsu automatically links a running target still active then',
    (tester) async {
      final now = DateTime(2026, 10, 29, 13);
      final ticks = StreamController<DateTime>();
      addTearDown(ticks.close);
      await withClock(Clock.fixed(now), () async {
        // Deliberately keep the unrelated target active across both visibility
        // boundaries, so hiding the future card cannot mask an association bug.
        await show(
          tester,
          now: now,
          runningTargetStart: now,
          runningTargetMinutes: 300,
          ticks: ticks.stream,
        );
        ticks.add(now);
        await tester.pumpAndSettle();
        expect(find.textContaining('Jujitsu'), findsNothing);
        ticks.add(DateTime(2026, 10, 29, 15, 29));
        await tester.pumpAndSettle();
        expect(find.textContaining('Jujitsu'), findsNothing);
        ticks.add(DateTime(2026, 10, 29, 15, 30));
        await tester.pumpAndSettle();
        expect(find.textContaining('Jujitsu'), findsOneWidget);
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(find.text('Temp target aktywności'), findsNothing);
        expect(find.textContaining('Przygotowanie:'), findsOneWidget);
        ticks.add(DateTime(2026, 10, 29, 16));
        await tester.pumpAndSettle();
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(find.textContaining('Przygotowanie:'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'a manual running target set inside the jujitsu preparation hour is automatically linked',
    (tester) async {
      final now = DateTime(2026, 10, 29, 16, 5);
      await withClock(Clock.fixed(now), () async {
        await show(
          tester,
          now: now,
          runningTargetStart: now,
          runningTargetMinutes: 90,
        );
        expect(find.textContaining('Jujitsu'), findsOneWidget);
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(find.text('Temp target aktywności'), findsNothing);
        expect(find.textContaining('Przygotowanie:'), findsOneWidget);
      });
    },
  );
}
