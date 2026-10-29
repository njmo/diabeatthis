import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../../data_sources/nightscout/temporary_targets/temp_target_service.dart';
import '../base/notifications_controller.dart';
import '../domain/events/temp_target_notification.dart';
import '../domain/models/notification_event.dart';
import '../providers/local_notifications_plugin_provider.dart';
import 'local_notifications_controller.dart';

class NotificationsControllerImpl implements NotificationsController {
  final Ref _ref;
  final NotificationsController _localController;
  final NotificationsController _inAppController;

  NotificationsControllerImpl(this._ref, this._inAppController)
    : _localController = LocalNotificationsController(
        _ref.read(localNotificationsPluginProvider),
      );

  @override
  Future<void> init() async {
    await _localController.init();
    await _inAppController.init();
  }

  @override
  Future<void> show(NotificationEvent event, {bool temporary = false}) async {
    if (event is TempTargetNotificationEvent) {
      final prepared = await _ref
          .read(tempTargetServiceProvider)
          .prepare(event);
      if (prepared == null) return;
      event = prepared;
    }
    final appLifecycleState = _ref.read(appLifecycleProvider);

    try {
      if (temporary && appLifecycleState == AppLifecycleState.resumed) {
        await _inAppController.show(event);
      } else {
        await _localController.show(event);
      }
      if (event is TempTargetNotificationEvent && event.requestId != null) {
        await _ref
            .read(tempTargetServiceProvider)
            .markDelivered(event.requestId!);
      }
    } catch (_) {
      if (event is TempTargetNotificationEvent && event.requestId != null) {
        _ref.read(tempTargetServiceProvider).deliveryFailed(event.requestId!);
      }
      rethrow;
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
