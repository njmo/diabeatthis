import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../application/notifications_controller.dart';
import '../domain/models/notification_event.dart';
import '../providers/local_notifications_plugin_provider.dart';
import 'in_app_notifications_controller.dart';
import 'local_notifications_controller.dart';

class NotificationsControllerImpl implements NotificationsController {
  final Ref _ref;
  final NotificationsController _localController;
  final NotificationsController _inAppController;

  NotificationsControllerImpl(this._ref, this._inAppController)
    :  _localController = LocalNotificationsController(
        _ref.read(localNotificationsPluginProvider),
      );

  @override
  Future<void> init() async {
    await _localController.init();
    await _inAppController.init();
  }

  @override
  Future<void> show(NotificationEvent event) async {
    final appLifecycleState = _ref.read(appLifecycleProvider);

    if (appLifecycleState == AppLifecycleState.resumed) {
      await _inAppController.show(event);
    } else {
      await _localController.show(event);
    }
  }

  @override
  Future<void> schedule(NotificationEvent event, Duration duration) async {
    await _localController.schedule(event, duration);
  }

  @override
  Future<void> cancel(int id) async {
    await _localController.cancel(id);
  }

  @override
  Future<void> cancelAll() async {
    await _localController.cancelAll();
  }

  @override
  Future<Iterable<int>> get pending =>
      switch (_ref.read(appLifecycleProvider)) {
        AppLifecycleState.resumed => _localController.pending,
        _ => Future.value(const []),
      };
}
