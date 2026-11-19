import 'dart:async';
import 'dart:ui' as ui;

import 'package:diabeatthis/common/family_sync/presentation/child_family_cloud_ribbon.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/charts/glucose_chart_timeline.dart';
import 'package:diabeatthis/common/presentation/dashboard/glucose_freshness.dart';
import 'package:diabeatthis/common/presentation/dashboard/glucose_freshness_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_refresh_state.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_visible_state_provider.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_nightscout_panel.dart';
import 'package:diabeatthis/features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/nightscout_utils.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/compact_loop_glucose_chart.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_glucose_reading.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/nightscout_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);
  Glucose sample(int ago) => Glucose(
    externalId: '$ago',
    source: GlucoseSource.cloud,
    date: now.subtract(Duration(minutes: ago)),
    sgv: 123,
    direction: 'Flat',
  );
  for (final caregiver in [false, true]) {
    testWidgets(
      'fresh device status cannot replace the value or age of a two-hour-old CGM: caregiver=$caregiver',
      (tester) async {
        final old = sample(120);
        final device = testDeviceStatus(
          date: now,
          iob: 0,
          cob: 0,
          tick: '+5',
          bg: 999,
        );
        final container = ProviderContainer(
          overrides: [
            timeNowProvider.overrideWith((ref) => Stream.value(now)),
            dashboardWallClockProvider.overrideWithValue(() => now),
            sensorAgeProvider.overrideWith((ref) async => null),
            canulaAgeProvider.overrideWith((ref) async => null),
            childFamilyCloudStateProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
            caregiverVisibleStateProvider.overrideWithValue(
              CaregiverRefreshState(
                snapshot: CaregiverNightscoutSnapshot(
                  glucose: [old],
                  deviceStatus: device,
                  targetFetched: true,
                  hasFailures: false,
                ),
              ),
            ),
          ],
        );
        container.read(deviceStatusUiProvider.notifier).update(device);
        container.read(bloodSugarReadingsListProvider.notifier).replaceAll([
          old,
        ]);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: caregiver
                    ? const CaregiverNightscoutPanel()
                    : const NightscoutPanel(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('123'), findsOneWidget);
        expect(find.text('999'), findsNothing);
        expect(
          find.textContaining(formatAgo(const Duration(hours: 2))),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('glucose-stale')), findsOneWidget);
        expect(
          tester
              .widget<DashboardGlucoseReading>(
                find.byType(DashboardGlucoseReading),
              )
              .readingAt,
          old.date,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      },
    );
  }
  test(
    'freshness expires at exactly ten minutes and unknown/future time is never current',
    () {
      expect(
        dashboardGlucoseIsStale(
          now.subtract(const Duration(minutes: 9, seconds: 59)),
          now,
        ),
        false,
      );
      expect(
        dashboardGlucoseIsStale(now.subtract(const Duration(minutes: 10)), now),
        true,
      );
      expect(
        dashboardGlucoseIsStale(now.subtract(const Duration(hours: 2)), now),
        true,
      );
      expect(dashboardGlucoseIsStale(null, now), true);
      expect(
        dashboardGlucoseIsStale(now.add(const Duration(seconds: 1)), now),
        true,
      );
    },
  );
  test('chart colors preserve the glucose range boundaries', () {
    final painter = DashboardGlucoseChartPainter(
      timeline: GlucoseChartTimeline([]),
      now: now,
      isDark: false,
      stale: false,
    );
    for (final value in [69, 251]) {
      expect(painter.colorFor(value), const Color(0xFFEF4444));
    }
    for (final value in [181, 250]) {
      expect(painter.colorFor(value), const Color(0xFFF59E0B));
    }
    for (final value in [70, 180]) {
      expect(painter.colorFor(value), const Color(0xFF10B981));
    }
  });
  test(
    'two-hour geometry preserves empty time before now and discards future readings',
    () {
      final timeline = GlucoseChartTimeline(
        [sample(130), sample(110), sample(105), sample(20), sample(-1)],
        maxReadings: 241,
        windowEnd: now,
      );
      expect(timeline.values.length, 3);
      expect(timeline.fractionAt(sample(20).date), closeTo(100 / 120, .0001));
      expect(timeline.segments.map((s) => s.length), [2, 1]);
    },
  );
  test(
    'six-minute timestamp jitter stays connected but a missing five-minute sample does not',
    () {
      final first = sample(0);
      final delayed = first.copyWith(
        date: first.date.add(const Duration(minutes: 6, milliseconds: 900)),
      );
      final missing = delayed.copyWith(
        date: delayed.date.add(const Duration(minutes: 10)),
      );
      final timeline = GlucoseChartTimeline([first, delayed, missing]);
      expect(timeline.segments.map((segment) => segment.length), [2, 1]);
      expect(timeline.values, [first, delayed, missing]);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'open glucose card becomes grey/struck and loses trend after ten minutes: dark=$dark',
      (tester) async {
        final ticks = StreamController<DateTime>();
        var wall = now;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              timeNowProvider.overrideWith((ref) => ticks.stream),
              dashboardWallClockProvider.overrideWithValue(() => wall),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Scaffold(
                body: DashboardGlucoseReading(
                  value: 123,
                  readingAt: now,
                  readings: [sample(0)],
                  showDeviceCards: false,
                  color: Colors.green,
                  trendIcon: Icons.trending_up,
                  change: '+4',
                ),
              ),
            ),
          ),
        );
        ticks.add(now);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('glucose-current')), findsOneWidget);
        expect(find.text('+4'), findsOneWidget);
        wall = now.add(const Duration(minutes: 10));
        ticks.add(wall);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('glucose-stale')), findsOneWidget);
        expect(
          tester.widget<Text>(find.text('123')).style!.decoration,
          TextDecoration.lineThrough,
        );
        expect(find.text('+4'), findsNothing);
        expect(find.byIcon(Icons.trending_up), findsNothing);
        expect(
          find.byKey(const ValueKey('glucose-chart-stale')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        unawaited(ticks.close());
        await tester.pump();
      },
    );
  }
  testWidgets('reading crosses its ten-minute deadline between clock ticks', (
    tester,
  ) async {
    final at = now.subtract(const Duration(minutes: 9, seconds: 59));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timeNowProvider.overrideWith((ref) => Stream.value(now)),
          dashboardWallClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DashboardGlucoseReading(
              value: 123,
              readingAt: at,
              readings: [sample(0).copyWith(date: at)],
              color: Colors.green,
              trendIcon: Icons.trending_up,
              showDeviceCards: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('glucose-current')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byKey(const ValueKey('glucose-current')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(const ValueKey('glucose-stale')), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsNothing);
  });
  for (final freshArrival in [false, true]) {
    testWidgets(
      'freshness uses actual wall time rather than a forty-second-old minute tick: new=$freshArrival',
      (tester) async {
        final actualNow = now.add(const Duration(seconds: 40));
        final measuredAt = freshArrival
            ? actualNow
            : now.subtract(const Duration(minutes: 9, seconds: 10));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              timeNowProvider.overrideWith((ref) => Stream.value(now)),
              dashboardWallClockProvider.overrideWithValue(() => actualNow),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DashboardGlucoseReading(
                  value: 123,
                  readingAt: measuredAt,
                  readings: [sample(0).copyWith(date: measuredAt)],
                  color: Colors.green,
                  trendIcon: Icons.trending_up,
                  showDeviceCards: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('glucose-current')), findsOneWidget);
        if (!freshArrival) {
          await tester.pump(const Duration(milliseconds: 9999));
          expect(find.byKey(const ValueKey('glucose-current')), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump();
          expect(find.byKey(const ValueKey('glucose-stale')), findsOneWidget);
        }
      },
    );
  }
  testWidgets(
    'explicit value without a measurement timestamp cannot borrow freshness from other history',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeNowProvider.overrideWith((ref) => Stream.value(now)),
            dashboardWallClockProvider.overrideWithValue(() => now),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DashboardGlucoseReading(
                value: 123,
                readings: [sample(0)],
                color: Colors.green,
                trendIcon: Icons.trending_up,
                showDeviceCards: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('glucose-stale')), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsNothing);
    },
  );
  testWidgets(
    'chart leaves the gap and the current-clock endpoint without a fabricated trace',
    (tester) async {
      final recorder = ui.PictureRecorder();
      DashboardGlucoseChartPainter(
        timeline: GlucoseChartTimeline(
          [sample(110), sample(105), sample(15), sample(10)],
          maxReadings: 241,
          windowEnd: now,
        ),
        now: now,
        isDark: false,
        stale: false,
      ).paint(ui.Canvas(recorder), const ui.Size(240, 100));
      final picture = recorder.endRecording();
      final image = (await tester.runAsync(() => picture.toImage(240, 100)))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      bool greenAt(int x) {
        for (var y = 0; y < 100; y++) {
          final index = (y * 240 + x) * 4;
          if (bytes.getUint8(index + 3) > 100 &&
              bytes.getUint8(index + 1) > bytes.getUint8(index) + 30) {
            return true;
          }
        }
        return false;
      }

      expect(greenAt(25), true);
      expect(greenAt(120), false);
      expect(greenAt(239), false);
      int alphaAt(int x, int y) => bytes.getUint8((y * 240 + x) * 4 + 3);
      expect(
        alphaAt(25, 80),
        greaterThan(alphaAt(120, 80)),
        reason: 'The history gradient fills a measured segment but not the gap',
      );
      image.dispose();
      picture.dispose();
    },
  );
}
