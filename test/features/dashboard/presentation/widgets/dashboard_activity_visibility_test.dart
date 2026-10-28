import 'dart:async';

import 'package:clock/clock.dart';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/temporary_target_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

final now = DateTime(2026, 10, 28, 17);
ActivityLogSummaryData activityAt(DateTime start) => ActivityLogSummaryData(
  id: 1,
  activityName: 'Jujitsu',
  activityId: 1,
  startedAt: start,
  endedAt: null,
  durationMinutes: 60,
);
Future<void> showCard(WidgetTester tester, DateTime start) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      getPendingActivityProvider.overrideWithValue(
        AsyncData(activityAt(start)),
      ),
      timeNowProvider.overrideWithValue(AsyncData(now)),
    ],
    child: localizedMaterialApp(
      home: const Scaffold(body: DashboardStatusCard()),
    ),
  ),
);

void main() {
  testWidgets('tomorrow and more distant activities stay off the dashboard', (
    tester,
  ) async {
    for (final days in [1, 2]) {
      await showCard(tester, now.add(Duration(days: days)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jujitsu'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
    'countdown appears at 90 minutes, but not before the preparation window',
    (tester) async {
      await showCard(tester, now.add(const Duration(minutes: 91)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jujitsu'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await showCard(tester, now.add(const Duration(minutes: 90)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jujitsu'), findsOneWidget);
      expect(
        find.textContaining(
          lookupAppLocalizations(
            const Locale('pl'),
          ).dashboardActivityStartsIn(90),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'an active activity remains visible regardless of how long ago it started',
    (tester) async {
      await showCard(tester, now.subtract(const Duration(hours: 4)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jujitsu'), findsOneWidget);
    },
  );
  testWidgets(
    'hiding a future activity does not hide an active temporary target',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        await showCard(tester, now.add(const Duration(days: 1)));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DashboardStatusCard)),
        );
        container
            .read(temporaryTargetUiProvider.notifier)
            .update(
              TemporaryTarget(
                nightscoutId: 'target',
                createdAt: now,
                durationInMiliseconds: 3600000,
                duration: 60,
                targetBottom: 140,
                targetTop: 140,
              ),
            );
        await tester.pumpAndSettle();
        expect(find.textContaining('Jujitsu'), findsNothing);
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('pl'),
            ).dashboardActivityTempTargetTitle,
          ),
          findsOneWidget,
        );
      });
    },
  );
  testWidgets(
    'the clock makes a planned activity visible without reopening the screen',
    (tester) async {
      final clock = StreamController<DateTime>();
      addTearDown(clock.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            getPendingActivityProvider.overrideWithValue(
              AsyncData(activityAt(now.add(const Duration(hours: 2)))),
            ),
            timeNowProvider.overrideWith((ref) => clock.stream),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(body: DashboardStatusCard()),
          ),
        ),
      );
      clock.add(now);
      await tester.pumpAndSettle();
      expect(find.textContaining('Jujitsu'), findsNothing);
      clock.add(now.add(const Duration(minutes: 30)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jujitsu'), findsOneWidget);
    },
  );
}
