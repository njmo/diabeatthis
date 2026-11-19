import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../../data_sources/nightscout/temporary_targets/temp_target_service.dart';
import '../../logger/logger.dart';
import '../base/notifications_controller.dart';
import '../definitions/notification_definition_catalog_impl.dart';
import '../domain/events/temp_target_notification.dart';
import '../domain/models/notification_event.dart';
import '../domain/models/notification_identity.dart';
import '../inbox/notification_inbox_entry.dart';
import '../inbox/notification_inbox_store.dart';

/// Routes a notification either to an in-app banner, while the user is looking
/// at the app, or to the operating system otherwise. Every delivered
/// notification is also mirrored into the [NotificationInboxStore].
class NotificationsControllerImpl implements NotificationsController {
  final Ref _ref;
  final NotificationsController _localController;
  final NotificationsController _inAppController;
  final Future<void> Function(NotificationEvent)? onShown;

  /// Whether the app UI is currently visible to the user. Defaults to this
  /// isolate's lifecycle state.
  final Future<bool> Function()? isAppVisible;

  /// Called after this isolate added entries to the inbox without going
  /// through the in-app controller.
  final void Function()? onInboxChanged;

  final NotificationInboxStore _inbox;

  NotificationsControllerImpl(
    this._ref,
    this._inAppController, {
    required this._localController,
    this.onShown,
    this.isAppVisible,
    this.onInboxChanged,
    NotificationInboxStore? inbox,
  }) : _inbox = inbox ?? NotificationInboxStore();

  @override
  Future<void> init() async {
    await _localController.init();
    await _inAppController.init();
  }

  Future<bool> _shouldPresentInApp(NotificationEvent event) async {
    if (!NotificationDefinitionCatalogImpl().byType(event.type).presentInApp) {
      return false;
    }
    if (_ref.read(appLifecycleProvider) != AppLifecycleState.resumed) {
      return false;
    }
    final probe = isAppVisible;
    if (probe == null) return true;
    try {
      return await probe();
    } catch (error) {
      Log.w('NotificationsController', 'Visibility probe failed ($error)');
      return false;
    }
  }

  @override
  Future<void> show(NotificationEvent event) async {
    if (event is TempTargetNotificationEvent) {
      final prepared = await _ref
          .read(tempTargetServiceProvider)
          .prepare(event);
      if (prepared == null) return;
      event = prepared;
    }

    try {
      var inApp = await _shouldPresentInApp(event);
      // Record before handing the event over: the UI re-shows unread in-app
      // entries from the inbox, so a banner message lost between isolates
      // still reaches the user.
      final stored = await _inbox.put(
        NotificationInboxEntry.fromEvent(
          event,
          id: notificationIdentity(event).id,
          createdAt: clock.now(),
          inApp: inApp,
        ),
      );
      // Without a durable copy a dismissed banner would be gone for good.
      if (!stored) inApp = false;
      if (inApp) {
        await _inAppController.show(event);
      } else {
        await _localController.show(event);
        onInboxChanged?.call();
      }
      if (onShown != null) {
        unawaited(
          Future<void>.sync(() => onShown!(event)).catchError((
            Object error,
            StackTrace stack,
          ) {
            Log.e(
              'NotificationsController',
              'Calculator state observer failed',
              error: error,
              stackTrace: stack,
            );
          }),
        );
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
    // Hidden in the inbox until it is due; cancelling it removes the entry.
    await _inbox.put(
      NotificationInboxEntry.fromEvent(
        event,
        id: notificationIdentity(event).id,
        createdAt: clock.now().add(duration),
      ),
    );
    // Lets the UI arm its refresh for when the entry becomes due.
    onInboxChanged?.call();
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    await _localController.cancel(id, tag: tag);
    await _inbox.cancel(id);
    await _guardInApp(() => _inAppController.cancel(id, tag: tag));
  }

  @override
  Future<void> cancelAll() async {
    await _localController.cancelAll();
    await _inbox.cancelAll();
    await _guardInApp(_inAppController.cancelAll);
  }

  Future<void> _guardInApp(Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      Log.w('NotificationsController', 'In-app cancellation failed ($error)');
    }
  }

  @override
  Future<Iterable<int>> get pending =>
      switch (_ref.read(appLifecycleProvider)) {
        AppLifecycleState.resumed => _localController.pending,
        _ => Future.value(const []),
      };
}
