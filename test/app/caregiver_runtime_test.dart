import 'package:diabeatthis/app/app.dart';
import 'package:diabeatthis/app/providers/app_event_router_provider.dart';
import 'package:diabeatthis/app/providers/app_foreground_bridge_provider.dart';
import 'package:diabeatthis/app/router/guards/initial_configuration_guard.dart';
import 'package:diabeatthis/app/router/providers/app_router_provider.dart';
import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/caregiver/application/refresh_caregiver_nightscout_use_case.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:diabeatthis/foreground/runtime/task_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/regression/recording_foreground_platform.dart';
import 'startup_permissions_test.dart'
    show StartupNotifications, StartupPermissionRouter;

class RuntimeCaregiverRefresh extends RefreshCaregiverNightscoutUseCase {
  RuntimeCaregiverRefresh(super.ref);
  int calls = 0;
  @override
  Future<CaregiverNightscoutSnapshot> call() async {
    calls++;
    return const CaregiverNightscoutSnapshot(
      glucose: [],
      targetFetched: true,
      hasFailures: false,
    );
  }
}

void main() {
  testWidgets(
    'saved caregiver mode refreshes visible UI without touching foreground transport',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        applicationDeviceModeKey: 'caregiver',
        initialConfigurationDoneKey: true,
        nightscoutUrlKey: 'https://nightscout.test',
        nightscoutTokenKey: 'read-token',
      });
      final prefs = await SharedPreferences.getInstance();
      var foregroundReads = 0;
      late RuntimeCaregiverRefresh refresh;
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          appForegroundBridgeProvider.overrideWith((ref) {
            foregroundReads++;
            throw StateError('Caregiver cannot initialize foreground');
          }),
          appEventRouterProvider.overrideWith(
            (ref) =>
                throw StateError('Caregiver cannot dispatch patient commands'),
          ),
          notificationsControllerUiProvider.overrideWithValue(
            StartupNotifications(),
          ),
          refreshCaregiverNightscoutProvider.overrideWith(
            (ref) => refresh = RuntimeCaregiverRefresh(ref),
          ),
          appRouterProvider.overrideWith(
            (ref) => StartupPermissionRouter(InitialConfigurationGuard(ref)),
          ),
          applicationLightThemeProvider.overrideWithValue(ThemeData()),
          applicationDarkThemeProvider.overrideWithValue(ThemeData.dark()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      expect(refresh.calls, 1);
      expect(foregroundReads, 0);
      final observer =
          tester.state(find.byType(MyApp)) as WidgetsBindingObserver;
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 31));
      expect(refresh.calls, 1);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(refresh.calls, 2);
      expect(foregroundReads, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'native automatic restart stops before creating child collectors in caregiver mode',
    () async {
      SharedPreferences.setMockInitialValues({
        applicationDeviceModeKey: 'caregiver',
      });
      final previous = FlutterForegroundTaskPlatform.instance;
      final skip = FlutterForegroundTask.skipServiceResponseCheck;
      final platform = RecordingForegroundPlatform()..running = true;
      FlutterForegroundTaskPlatform.instance = platform;
      FlutterForegroundTask.skipServiceResponseCheck = true;
      addTearDown(() {
        FlutterForegroundTaskPlatform.instance = previous;
        FlutterForegroundTask.skipServiceResponseCheck = skip;
      });
      await MyTaskHandler().onStart(DateTime.now(), TaskStarter.system);
      expect(platform.calls, ['stop']);
      expect(platform.running, isFalse);
    },
  );
}
