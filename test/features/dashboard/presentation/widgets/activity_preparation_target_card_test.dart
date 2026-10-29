import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/temporary_targets/owned_temp_target.dart';
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
  final now = DateTime(2026, 10, 29, 14);
  final targetStart = now.subtract(const Duration(minutes: 1));
  const source = 'https://example.com';

  OwnedTempTarget owner({
    int activityId = 42,
    String url = source,
    String? id = 'owned-target',
  }) => OwnedTempTarget(
    entityId: activityId,
    targetType: 'activity',
    source: url,
    startedAt: targetStart,
    until: targetStart.add(const Duration(minutes: 90)),
    target: 140,
    durationMinutes: 90,
    nightscoutId: id,
  );

  Future<ProviderContainer> show(
    WidgetTester tester, {
    OwnedTempTarget? owned,
    DateTime? activityStart,
    String? targetId = 'owned-target',
    bool observeTarget = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: source,
      if (owned != null)
        nightscoutOwnedTempTargetKey: jsonEncode(owned.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWith((_) async => prefs),
          getPendingActivityProvider.overrideWithValue(
            AsyncData(
              ActivityLogSummaryData(
                id: 42,
                activityName: 'rower',
                activityId: 7,
                startedAt:
                    activityStart ?? now.add(const Duration(minutes: 59)),
                endedAt: null,
                durationMinutes: null,
              ),
            ),
          ),
          timeNowProvider.overrideWithValue(AsyncData(now)),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(body: DashboardStatusCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardStatusCard)),
    );
    if (observeTarget) {
      container
          .read(temporaryTargetUiProvider.notifier)
          .update(
            TemporaryTarget(
              nightscoutId: targetId,
              createdAt: targetStart,
              durationInMiliseconds: 5400000,
              duration: 90,
              targetBottom: 140,
              targetTop: 140,
            ),
          );
      await tester.pumpAndSettle();
    }
    return container;
  }

  testWidgets(
    'a target started an hour before activity is shown as preparation inside one activity card',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        await show(tester, owned: owner());
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(find.text('Zaplanowana aktywność'), findsOneWidget);
        expect(find.textContaining('rower'), findsOneWidget);
        expect(
          find.text('Przygotowanie: temp target 140 mg/dl'),
          findsOneWidget,
        );
        expect(find.textContaining('Pozostało 89 min'), findsOneWidget);
        expect(find.text('Temp target aktywności'), findsNothing);
      });
    },
  );

  testWidgets(
    'a target arriving later updates the existing activity card without reopening the screen',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final container = await show(
          tester,
          owned: owner(),
          observeTarget: false,
        );
        expect(find.textContaining('Przygotowanie: temp target'), findsNothing);
        container
            .read(temporaryTargetUiProvider.notifier)
            .update(
              TemporaryTarget(
                nightscoutId: 'owned-target',
                createdAt: targetStart,
                durationInMiliseconds: 5400000,
                duration: 90,
                targetBottom: 140,
                targetTop: 140,
              ),
            );
        await tester.pumpAndSettle();
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(
          find.text('Przygotowanie: temp target 140 mg/dl'),
          findsOneWidget,
        );
      });
    },
  );

  testWidgets('during the activity the same card labels its ongoing target', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      await show(
        tester,
        owned: owner(),
        activityStart: now.subtract(const Duration(minutes: 10)),
      );
      expect(find.byType(StatusInfoCard), findsOneWidget);
      expect(find.text('Temp target aktywności: 140 mg/dl'), findsOneWidget);
      expect(find.textContaining('Przygotowanie:'), findsNothing);
    });
  });

  for (final variant in [
    'external',
    'another activity',
    'another source',
    'replacement',
  ]) {
    testWidgets(
      'a target from $variant is automatically linked while the activity is visible',
      (tester) async {
        await withClock(Clock.fixed(now), () async {
          await show(
            tester,
            owned: variant == 'external'
                ? null
                : owner(
                    activityId: variant == 'another activity' ? 99 : 42,
                    url: variant == 'another source'
                        ? 'https://other.example.com'
                        : source,
                  ),
            targetId: variant == 'replacement'
                ? 'manual-target'
                : 'owned-target',
          );
          expect(find.byType(StatusInfoCard), findsOneWidget);
          expect(find.text('Temp target aktywności'), findsNothing);
          expect(
            find.textContaining('Przygotowanie: temp target'),
            findsOneWidget,
          );
        });
      },
    );
  }

  testWidgets(
    'a successfully sent target without a returned ID can be matched by its exact fingerprint',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        await show(tester, owned: owner(id: null));
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(
          find.text('Przygotowanie: temp target 140 mg/dl'),
          findsOneWidget,
        );
      });
    },
  );

  testWidgets(
    'an observation without a remote ID can match the exact owned target fingerprint',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        await show(tester, owned: owner(), targetId: null);
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(
          find.text('Przygotowanie: temp target 140 mg/dl'),
          findsOneWidget,
        );
      });
    },
  );

  testWidgets(
    'activities explicitly attached to existing targets retain their association',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        await show(tester, activityStart: targetStart);
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(find.text('Temp target aktywności: 140 mg/dl'), findsOneWidget);
      });
    },
  );
}
