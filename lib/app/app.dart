import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/data/provider/monitor_service_enabled_provider.dart';
import '../core/foreground_service/handler/TaskHandler.dart';
import 'providers/app_init_provider.dart';
import 'providers/app_lifecycle_state_provider.dart';
import 'router/observers/router_debug_observer.dart';
import 'router/providers/app_router_provider.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  void _onReceiveTaskData(Object data) {
    // ref to handle
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    Future.microtask(() async {
      await ref.read(appInitProvider.future);
      final enabled = ref.read(monitorServiceEnabledProvider);

      if (enabled) {
        final isRunning = await FlutterForegroundTask.isRunningService;

        if (!isRunning) {
          await FlutterForegroundTask.startService(
            serviceId: 256,
            notificationTitle: 'Monitoring aktywny',
            notificationText: 'Uruchamianie...',
            callback: startCallback,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleProvider.notifier).setState(state);
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
