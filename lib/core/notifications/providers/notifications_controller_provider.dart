import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/meal/calculator/calculator_instruction_event.dart';
import '../../../common/meal/calculator/meal_calculator_request_controller_provider.dart';
import '../base/notifications_controller.dart';
import '../controllers/foreground_task_notification_controller.dart';
import '../controllers/in_app_notifications_controller.dart';
import '../controllers/notifications_controller_impl.dart';
import '../domain/models/notification_event.dart';
import '../in_app/in_app_notification_center.dart';
import 'local_notifications_controller_provider.dart';

part 'notifications_controller_provider.g.dart';

@Riverpod(keepAlive: true)
NotificationsController notificationsControllerUi(Ref ref) {
  final notificationsController = NotificationsControllerImpl(
    ref,
    InAppNotificationsController(ref),
    localController: ref.watch(localNotificationsControllerProvider),
    onInboxChanged: () =>
        unawaited(ref.read(inAppNotificationCenterProvider.notifier).refresh()),
  );

  return notificationsController;
}

@Riverpod(keepAlive: true)
NotificationsController notificationsControllerForeground(Ref ref) {
  final inApp = ForegroundTaskNotificationController(ref);
  final notificationsController = NotificationsControllerImpl(
    ref,
    inApp,
    localController: ref.watch(localNotificationsControllerProvider),
    // The service isolate only learns the UI lifecycle through messages, which
    // stop arriving when the UI process dies; confirm with the platform.
    isAppVisible: () => FlutterForegroundTask.isAppOnForeground,
    onInboxChanged: inApp.notifyInboxChanged,
    onShown: (event) async {
      final instruction = calculatorInstructionEvent(event);
      if (instruction == null ||
          (instruction.carbs == 0 && instruction.extendedCarbs == 0)) {
        return;
      }
      await ref
          .read(mealCalculatorRequestControllerProvider)
          .register(instruction);
    },
  );

  return notificationsController;
}

/// Delivery for work that runs without the app UI, such as push handlers and
/// notification responses in a headless container: system notifications,
/// still mirrored into the inbox. The app UI uses [notificationsControllerUi].
final notificationsControllerHeadlessProvider =
    Provider<NotificationsController>(
      (ref) => NotificationsControllerImpl(
        ref,
        const _NoInAppNotifications(),
        localController: ref.watch(localNotificationsControllerProvider),
        isAppVisible: () async => false,
      ),
    );

class _NoInAppNotifications implements NotificationsController {
  const _NoInAppNotifications();

  @override
  Future<void> init() async {}

  @override
  Future<void> show(NotificationEvent event) async {}

  @override
  Future<void> schedule(NotificationEvent event, Duration when) async {}

  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<Iterable<int>> get pending async => const [];
}
