import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/task/task_data_synchronization_payload.dart';
import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/foreground/alarm/foreground_alarm_bridge.dart';
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_handler.dart';
import 'package:diabeatthis/foreground/event/internal/data_available_event.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_runtime_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDeviceStatusHandler', () {
    final alarmChannel = const MethodChannel(
      AndroidAlarmManager.channelName,
      JSONMethodCodec(),
    );
    final alarmCalls = <MethodCall>[];

    setUp(() async {
      AndroidAlarmManager.setTestOverrides(
        getCallbackHandle: (_) => CallbackHandle.fromRawHandle(1),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(alarmChannel, (call) async {
            alarmCalls.add(call);
            return true;
          });
      await ForegroundAlarmBridge.cancelCollectTick();
      alarmCalls.clear();
    });

    tearDown(() async {
      await ForegroundAlarmBridge.cancelCollectTick();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(alarmChannel, null);
    });

    test(
      'updates live state and schedules safety tick for matching AAPS source',
      () async {
        final now = DateTime(2026, 5, 18, 12, 30);
        final deviceStatus = DeviceStatus(
          externalId: 'status-1',
          source: DeviceStatusSource.aaps,
          date: now,
          iob: 0.663,
          basalIob: -0.214,
          bolusIob: 0.877,
          insulinActivity: 0.0116,
          cob: 17.94,
          tick: '+15',
          bg: 249,
          carbsReq: 3,
          carbsReqWithin: 0,
          sensitivityRatio: 1,
          isfMgdlForCarbs: 180,
          baseBasalRate: 0.35,
          tempBasalRemainingMinutes: 95,
          lastBolusAmount: 0.8,
          lastBolusAt: '18.05.2026 19:50',
        );
        final router = RecordingTaskEventRouter();
        final container = ProviderContainer(
          overrides: [
            dataSourceConfigProvider.overrideWithValue(
              const AsyncData(
                DataSourceConfig(
                  bgSource: BgSource.cloud,
                  treatmentsSource: TreatmentsSource.cloud,
                  pumpStatusSource: PumpStatusSource.aaps,
                  historySource: HistorySource.cloud,
                  mirrorToLocal: false,
                ),
              ),
            ),
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);

        await withClock(Clock.fixed(now), () async {
          await LocalDeviceStatusHandler().handle(
            LocalDeviceStatusEvent(data: deviceStatus),
            harness.runtimeContext,
          );
        });

        expect(container.read(deviceStatusValueProvider), deviceStatus);
        expect(
          container
              .read(synchronizationCacheControllerProvider)
              .getCache()
              .deviceStatusCache,
          deviceStatus,
        );
        expect(harness.emittedEvents, [
          isA<DataAvailableEvent<DeviceStatus>>(),
        ]);
        expect(harness.emittedTicks, [now]);
        expect(router.payloads, [
          TaskDeviceStatusSynchronization(data: deviceStatus),
        ]);
        final oneShotCall = alarmCalls.lastWhere(
          (call) => call.method == 'Alarm.oneShotAt',
        );
        final arguments = oneShotCall.arguments as List<dynamic>;

        expect(arguments[0], ForegroundAlarmBridge.collectAlarmId);
        expect(arguments[3], isTrue);
        expect(arguments[4], isTrue);
        expect(
          arguments[5],
          now.add(const Duration(minutes: 6)).millisecondsSinceEpoch,
        );

        await harness.dispose();
      },
    );
  });
}

class RecordingTaskEventRouter extends TaskEventRouter {
  final List<TaskEventPayload> payloads = [];

  @override
  void send(TaskEventPayload payload) {
    payloads.add(payload);
  }
}
