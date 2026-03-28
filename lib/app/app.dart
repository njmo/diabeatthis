import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../common/events/data/app/execute_command_event.dart';
import '../common/events/data/app/lifecycle_state_event.dart';
import '../common/events/data/app_event_data.dart';
import '../core/data/provider/monitor_service_enabled_provider.dart';
import '../core/logger/logger.dart';
import '../core/notifications/providers/notifications_controller_provider.dart';
import 'event/task/task_event_handler.dart';
import 'lifecycle/app_foreground_bridge.dart';
import 'providers/app_event_router_provider.dart';
import 'providers/app_lifecycle_state_provider.dart';
import 'router/observers/router_debug_observer.dart';
import 'router/providers/app_router_provider.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp>
    with WidgetsBindingObserver, Logging {
  final AppForegroundBridge _foregroundBridge = AppForegroundBridge();
  late TaskEventHandler? _taskEventHandler;

  void _onReceiveTaskData(Object data) {
    if (data is String) {
      final map = jsonDecode(data) as Map<String, dynamic>;
      _taskEventHandler!.handle(map);
    }
    logI('onReceiveData: $data');
  }

  Future<void> prepareApp() async {
    await Permission.activityRecognition.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.notification.request();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _foregroundBridge.attach(_onReceiveTaskData);

    _taskEventHandler = TaskEventHandler(ref);

    Future.microtask(() async {
      await prepareApp();
      await ref.read(notificationsControllerUiProvider).init();
      await _foregroundBridge.init();

      final enabled = ref.read(monitorServiceEnabledProvider);
      if (enabled) {
        final isServiceRunning = await _foregroundBridge.isServiceRunning();
        if (!isServiceRunning) {
          await _foregroundBridge.startMonitoring();
        } else {
          logI("Foreground task is running, requesting data sync");
          sendSyncCommand();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundBridge.detach(_onReceiveTaskData);
    super.dispose();
  }

  void sendSyncCommand() {
    final appEventRouter = ref.read(appEventRouterProvider);
    final syncCommand = ExecuteCommandEvent.syncData(data: []);
    appEventRouter.send(syncCommand);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appEventRouter = ref.read(appEventRouterProvider);
    ref.read(appLifecycleProvider.notifier).setState(state);
    logI('sending ${state.toString()}');
    if (state == AppLifecycleState.resumed) {
      logI("App resumed, requesting data sync");
      sendSyncCommand();
    }

    final AppEventData payload = LifecycleStateEvent.changed(
      state: state.index,
    );
    appEventRouter.send(payload);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router.config(
        navigatorObservers: () => [AutoRouteDebugObserver()],
      ),
      theme: ThemeData(
        textTheme: GoogleFonts.nunitoSansTextTheme(),
        useMaterial3: true,
      ),
    );
  }
}
