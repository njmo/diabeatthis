import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/device_status_dashboard.dart';
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_handler.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';
import '../../helpers/foreground_ui/foreground_glucose_test_view.dart';
import '../../helpers/foreground_ui/foreground_to_ui_test_router.dart';
import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/localized_material_app.dart';

void main() {
  final now = DateTime(2026, 11, 3, 12);
  const config = DataSourceConfig(
    bgSource: BgSource.aaps,
    treatmentsSource: TreatmentsSource.aaps,
    pumpStatusSource: PumpStatusSource.aaps,
    historySource: HistorySource.local,
    mirrorToLocal: false,
  );
  DeviceStatus reading({
    int minutesAgo = 0,
    DeviceStatusSource source = DeviceStatusSource.aaps,
    double iob = 1.25,
    int bg = 140,
  }) => testDeviceStatus(
    date: now.subtract(Duration(minutes: minutesAgo)),
    source: source,
    iob: iob,
    cob: 8.5,
    tick: '0',
    bg: bg,
  );
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidAlarmManager.channel,
          (call) async => true,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidAlarmManager.channel, null);
  });

  Future<void> scenario(
    WidgetTester tester,
    Future<void> Function(ForegroundUiHarness, ForegroundToUiTestRouter) body,
  ) async {
    final transport = ForegroundToUiTestRouter();
    final harness = (await tester.runAsync(
      () => ForegroundUiHarness.create(
        meals: false,
        foregroundOverrides: [
          dataSourceConfigProvider.overrideWith((ref) async => config),
          taskEventRouterProvider.overrideWithValue(transport),
        ],
      ),
    ))!;
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.uiContainer,
          child: localizedMaterialApp(
            home: ForegroundGlucoseTestView(
              transport: transport,
              showDeviceStatus: true,
            ),
          ),
        ),
      );
      await body(harness, transport);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(harness.close);
    }
  }

  Future<void> send(
    WidgetTester tester,
    ForegroundUiHarness harness,
    DeviceStatus value,
  ) async {
    await LocalDeviceStatusHandler().handle(
      LocalDeviceStatusEvent(data: value),
      harness.runtimeContext,
    );
    await tester.pump();
  }

  for (final kind in ['fresh', 'wrong-source', 'invalid-bg']) {
    testWidgets(
      'device status reaches the production dashboard consistently: $kind',
      (tester) => withClock(
        Clock.fixed(now),
        () => scenario(tester, (harness, transport) async {
          await send(tester, harness, reading());
          expect(find.byType(DeviceStatusDashboard), findsOneWidget);
          expect(find.text('1.25 U'), findsOneWidget);
          expect(find.text('8.50 g'), findsOneWidget);
          expect(
            harness.foregroundContainer.read(deviceStatusValueProvider)?.iob,
            1.25,
          );
          if (kind != 'fresh') {
            await send(
              tester,
              harness,
              reading(
                source: kind == 'wrong-source'
                    ? DeviceStatusSource.cloud
                    : DeviceStatusSource.aaps,
                iob: 9,
                bg: kind == 'invalid-bg' ? 0 : 140,
              ),
            );
            expect(transport.messages, hasLength(1));
            expect(find.text('1.25 U'), findsOneWidget);
            expect(
              harness.foregroundContainer.read(deviceStatusValueProvider)?.iob,
              1.25,
            );
          }
          expect(tester.takeException(), isNull);
        }),
      ),
    );
  }

  for (final age in [2, 7]) {
    testWidgets(
      'late $age minute old pump status cannot replace newer IOB in foreground or UI',
      (tester) => withClock(
        Clock.fixed(now),
        () => scenario(tester, (harness, transport) async {
          await send(tester, harness, reading());
          expect(find.text('1.25 U'), findsOneWidget);
          await send(tester, harness, reading(minutesAgo: age, iob: 9));
          expect(
            (
              harness.foregroundContainer.read(deviceStatusValueProvider)?.iob,
              tester
                  .widget<DeviceStatusDashboard>(
                    find.byType(DeviceStatusDashboard),
                  )
                  .deviceStatus
                  .iob,
            ),
            (1.25, 1.25),
          );
          expect(find.text('1.25 U'), findsOneWidget);
          expect(find.text('9.00 U'), findsNothing);
        }),
      ),
    ); // Regression: a delayed device status rolls IOB back or clears the foreground's current sample.
  }
}
