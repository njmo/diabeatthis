import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/data/provider/monitor_service_enabled_provider.dart';
import '../core/local_notifications/providers/local_notifications_controller_provider.dart';
import 'lifecycle/app_foreground_bridge.dart';
import 'providers/app_lifecycle_state_provider.dart';
import 'router/observers/router_debug_observer.dart';
import 'router/providers/app_router_provider.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  final AppForegroundBridge _foregroundBridge = AppForegroundBridge();

  void _onReceiveTaskData(Object data) {
    // ref to handle
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _foregroundBridge.attach(_onReceiveTaskData);

    Future.microtask(() async {
      await ref.read(localNotificationsControllerProvider).init();
      final enabled = ref.read(monitorServiceEnabledProvider);
      if (enabled) {
        await _foregroundBridge.startMonitoring();
      }

    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundBridge.detach(_onReceiveTaskData);
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
