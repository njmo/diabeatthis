import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../common/app_mode/application_device_mode.dart';
import '../common/events/data/app/execute_command_event.dart';
import '../common/events/data/app/lifecycle_state_event.dart';
import '../common/events/data/app/sync_data_key.dart';
import '../common/events/data/app_event_data.dart';
import '../common/family_chat/notifications/family_chat_notifications_runtime.dart';
import '../common/l10n/application_language.dart';
import '../common/l10n/language.dart';
import '../common/location/residence_country_provider.dart';
import '../common/meal_advisor/presentation/remote/meal_decision_runtime.dart';
import '../common/theme/application_theme_data.dart';
import '../common/theme/application_theme_mode_controller.dart';
import '../common/widgets/application_backdrop.dart';
import '../core/data/provider/initial_configuration_provider.dart';
import '../core/data/provider/monitor_service_enabled_provider.dart';
import '../core/logger/logger.dart';
import '../core/notifications/in_app/widgets/in_app_notification_host.dart';
import '../core/notifications/providers/notifications_controller_provider.dart';
import '../features/caregiver/application/caregiver_ui_refresh_provider.dart';
import '../features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import '../features/dashboard/data/providers/device_status_ui_provider.dart';
import 'event/task/task_event_handler.dart';
import 'lifecycle/app_foreground_bridge.dart';
import 'providers/app_event_router_provider.dart';
import 'providers/app_foreground_bridge_provider.dart';
import 'providers/app_lifecycle_state_provider.dart';
import 'providers/foreground_task_state_provider.dart';
import 'router/observers/router_debug_observer.dart';
import 'router/providers/app_router_provider.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp>
    with WidgetsBindingObserver, Logging {
  AppForegroundBridge? _foregroundBridge;
  TaskEventHandler? _taskEventHandler;
  ApplicationDeviceMode? _activeMode;
  ProviderSubscription<AsyncValue<ApplicationDeviceMode>>? _modeSubscription;
  bool _patientAttached = false;
  int _modeRevision = 0;

  void _onReceiveTaskData(Object data) {
    if (_activeMode != ApplicationDeviceMode.patient ||
        _taskEventHandler == null) {
      return;
    }
    if (data is String) {
      final map = jsonDecode(data) as Map<String, dynamic>;
      _taskEventHandler!.handle(map);
    } else {
      logW('UI received unsupported task data ${data.runtimeType}');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() async {
      try {
        await ref.read(notificationsControllerUiProvider).init();
      } catch (error) {
        logW('Could not initialize UI notifications (${error.runtimeType})');
      }
      if (!mounted) return;
      _modeSubscription = ref.listenManual(applicationDeviceModeProvider, (
        _,
        next,
      ) {
        final mode = next.asData?.value;
        if (mode != null) unawaited(_configureMode(mode));
      }, fireImmediately: true);
    });
  }

  Future<void> _configureMode(ApplicationDeviceMode mode) async {
    if (!mounted || _activeMode == mode) return;
    final revision = ++_modeRevision;
    _activeMode = mode;
    if (mode == ApplicationDeviceMode.caregiver) {
      final hadPatient = _patientAttached;
      if (hadPatient) _foregroundBridge?.detach(_onReceiveTaskData);
      _patientAttached = false;
      _taskEventHandler?.dispose();
      _taskEventHandler = null;
      if (hadPatient) {
        try {
          final running = await _foregroundBridge!.isServiceRunning();
          if (mounted && revision == _modeRevision && running) {
            await _foregroundBridge!.controller.stop();
          }
        } catch (error) {
          logW(
            'Could not stop the previous patient service (${error.runtimeType})',
          );
        }
      }
      return;
    }
    try {
      // Keep the bridge non-null across asynchronous lifecycle callbacks.
      // ignore: omit_local_variable_types
      final AppForegroundBridge bridge =
          _foregroundBridge ?? ref.read(appForegroundBridgeProvider);
      _foregroundBridge = bridge;
      bridge.attach(_onReceiveTaskData);
      _patientAttached = true;
      _taskEventHandler = TaskEventHandler(ref);
      await bridge.init();
      if (!mounted || revision != _modeRevision) return;
      if (ref.read(monitorServiceEnabledProvider)) {
        final running = await bridge.isServiceRunning();
        if (!mounted || revision != _modeRevision) return;
        if (running) {
          sendSyncCommand();
        } else if (await ref.read(initialConfigurationDoneProvider.future)) {
          if (!mounted || revision != _modeRevision) return;
          final taskState = ref.read(foregroundTaskStateProvider.notifier);
          try {
            await bridge.startMonitoring();
            await taskState.waitForStartupMessage();
            if (mounted && revision == _modeRevision) sendSyncCommand();
          } catch (error) {
            logW('Foreground startup failed (${error.runtimeType})');
          }
        }
      }
      if (mounted && revision == _modeRevision) {
        await _taskEventHandler?.recoverPendingMealCompletions();
      }
    } catch (error) {
      logW('Patient runtime initialization failed (${error.runtimeType})');
    }
  }

  @override
  void dispose() {
    _taskEventHandler?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _modeSubscription?.close();
    if (_patientAttached) _foregroundBridge?.detach(_onReceiveTaskData);
    super.dispose();
  }

  void sendSyncCommand() {
    if (_activeMode != ApplicationDeviceMode.patient || !_patientAttached) {
      return;
    }
    _foregroundBridge!.reInitCommunicationPort();

    final appEventRouter = ref.read(appEventRouterProvider);
    final bloodSugarReadings = ref.read(
      bloodSugarReadingsListProvider.notifier,
    );
    final deviceStatusProvider = ref.read(deviceStatusUiProvider.notifier);
    final syncList = [
      if (bloodSugarReadings.syncNeeded()) SyncDataKey.glucoseList,
      if (deviceStatusProvider.isUpdateNeeded()) SyncDataKey.deviceStatus,
      SyncDataKey.temporaryTarget,
    ];
    if (syncList.isNotEmpty) {
      logI("Sending sync command with $syncList");
      final syncCommand = ExecuteCommandEvent.syncData(data: syncList);
      appEventRouter.send(syncCommand);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleProvider.notifier).setState(state);
    logI('sending ${state.toString()}');
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(deviceCountryLocalesProvider);
      _taskEventHandler?.retryPendingUiActions();
      logI("App resumed, requesting data sync");
      sendSyncCommand();
    }

    if (_activeMode != ApplicationDeviceMode.patient) return;
    final appEventRouter = ref.read(appEventRouterProvider);
    final AppEventData payload = LifecycleStateEvent.changed(
      state: state.index,
    );
    appEventRouter.send(payload);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.invalidate(deviceCountryLocalesProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(caregiverUiRefreshProvider);
    final router = ref.watch(appRouterProvider);
    final selectedLanguage = ref
        .watch(applicationLanguageControllerProvider)
        .maybeWhen(data: (language) => language, orElse: () => null);

    return MaterialApp.router(
      builder: (context, child) => InAppNotificationHost(
        child: ApplicationBackdrop(
          child: FamilyChatNotificationRuntime(
            child: MealDecisionRuntime(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
      locale: selectedLanguage?.locale,
      onGenerateTitle: (context) => context.lang.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router.config(
        navigatorObservers: () => [AutoRouteDebugObserver()],
      ),
      theme: ref.watch(applicationLightThemeProvider),
      darkTheme: ref.watch(applicationDarkThemeProvider),
      themeMode:
          ref.watch(applicationThemeModeControllerProvider).asData?.value ??
          ThemeMode.system,
    );
  }
}
