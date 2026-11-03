import 'dart:async';

import 'package:diabeatthis/common/monitoring/activity_monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_status.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/collector/foreground_collector.dart';
import 'package:diabeatthis/foreground/collector/meal_status_collector.dart';
import 'package:diabeatthis/foreground/collector/next_activity_collector.dart';
import 'package:diabeatthis/foreground/collector/next_meal_collector.dart';
import 'package:diabeatthis/foreground/event/internal/monitoring_status_changed.dart';
import 'package:diabeatthis/foreground/runtime/event_inbox.dart';
import 'package:diabeatthis/foreground/runtime/foreground_runtime_disposer.dart';
import 'package:diabeatthis/foreground/runtime/workflow_scheduler.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:diabeatthis/foreground/task/base/runtime_context.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/activity_monitor_task.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../../foreground/utils/pending_notifications_controller.dart';

/// Runs production foreground collectors and monitor tasks against a database
/// shared with a separate UI provider container.
class ForegroundUiHarness {
  final DriftIsolate _databaseServer;

  final DatabaseImpl uiDb;
  final DatabaseImpl foregroundDb;
  final ProviderContainer uiContainer;
  final ProviderContainer foregroundContainer;
  final PendingNotificationsController notifications;
  final WorkflowScheduler scheduler;
  final RuntimeContext runtimeContext;
  final MealMonitorTask mealMonitor;
  final ActivityMonitorTask activityMonitor;

  final bool _meals;
  final bool _activities;
  final List<ForegroundCollector> _collectors = [];
  late final EventInbox<MonitoringStatusChanged> _statusEvents;
  MealMonitoringStatus? _mealStatus;
  ActivityMonitoringStatus? _activityStatus;

  void _readStatusEvents() {
    if (_closed) return;
    for (final event in _statusEvents.drain()) {
      switch (event) {
        case MealMonitoringStatusChanged(:final status):
          _mealStatus = status;
        case ActivityMonitoringStatusChanged(:final status):
          _activityStatus = status;
      }
    }
  }

  MealMonitoringStatus? get mealStatus {
    _readStatusEvents();
    return _mealStatus;
  }

  ActivityMonitoringStatus? get activityStatus {
    _readStatusEvents();
    return _activityStatus;
  }

  bool _started = false;
  bool _closed = false;

  ForegroundUiHarness._({
    required this._databaseServer,
    required this.uiDb,
    required this.foregroundDb,
    required this.uiContainer,
    required this.foregroundContainer,
    required this.notifications,
    required this.scheduler,
    required this.runtimeContext,
    required this.mealMonitor,
    required this.activityMonitor,
    required this._meals,
    required this._activities,
  }) {
    _statusEvents = runtimeContext.openEventInbox<MonitoringStatusChanged>();
  }

  /// Creates independent UI and foreground clients backed by one in-memory DB.
  static Future<ForegroundUiHarness> create({
    bool meals = true,
    bool activities = false,
    PendingNotificationsController? notificationController,
    Map<String, Object> initialPreferences = const {},
    List<Override> uiOverrides = const [],
    List<Override> foregroundOverrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues(initialPreferences);
    final preferences = await SharedPreferences.getInstance();
    final databaseServer = DriftIsolate.inCurrent(
      () => NativeDatabase.memory(),
    );
    final uiDb = DatabaseImpl(await databaseServer.connect());
    final foregroundDb = DatabaseImpl(await databaseServer.connect());
    final notifications =
        notificationController ?? PendingNotificationsController();
    final uiContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(uiDb),
        sharedPrefsProvider.overrideWith((ref) async => preferences),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
        ...uiOverrides,
      ],
    );
    final foregroundContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(foregroundDb),
        sharedPrefsProvider.overrideWith((ref) async => preferences),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        ...foregroundOverrides,
      ],
    );
    final scheduler = WorkflowScheduler();

    return ForegroundUiHarness._(
      databaseServer: databaseServer,
      uiDb: uiDb,
      foregroundDb: foregroundDb,
      uiContainer: uiContainer,
      foregroundContainer: foregroundContainer,
      notifications: notifications,
      scheduler: scheduler,
      runtimeContext: scheduler.createContext(foregroundContainer),
      mealMonitor: MealMonitorTask(),
      activityMonitor: ActivityMonitorTask(),
      meals: meals,
      activities: activities,
    );
  }

  /// Starts real task loops and database collectors after tests seed the DB.
  void startMonitoring() {
    if (_closed) throw StateError('Harness is already closed.');
    if (_started) return;
    _started = true;

    if (_meals) scheduler.startTask(mealMonitor, runtimeContext);
    if (_activities) scheduler.startTask(activityMonitor, runtimeContext);

    final collectorContext = CollectorContext.fromRuntimeContext(
      runtimeContext,
    );
    if (_meals) {
      _collectors
        ..add(NextMealCollector())
        ..add(MealStatusCollector());
    }
    if (_activities) _collectors.add(NextActivityCollector());
    for (final collector in _collectors) {
      collector.start(collectorContext);
    }
  }

  /// Stops collectors, workflow tasks, containers, DB clients, and DB server.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await ForegroundRuntimeDisposer().dispose(
      scheduler: scheduler,
      collectors: _collectors,
      container: foregroundContainer,
    );
    uiContainer.dispose();
    // Let outstanding collector reads finish after disposal before closing
    // their transport; each collector observes its disposed flag on return.
    if (foregroundDb.hasOpened) {
      await foregroundDb.customSelect('SELECT 1 AS drained').get();
    }
    await foregroundDb.close();
    await uiDb.close();
    await _databaseServer.shutdownAll();
  }
}
