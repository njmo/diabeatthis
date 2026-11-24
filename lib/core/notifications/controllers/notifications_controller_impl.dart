import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../../data_sources/nightscout/temporary_targets/temp_target_service.dart';
import '../../logger/logger.dart';
import '../base/notifications_controller.dart';
import '../definitions/notification_definition_catalog_impl.dart';
import '../domain/events/family_chat_notification.dart';
import '../domain/events/notification_event_factory.dart';
import '../domain/events/temp_target_notification.dart';
import '../domain/models/notification_event.dart';
import '../domain/models/notification_identity.dart';
import '../domain/models/notification_retry_policy.dart';
import '../inbox/notification_inbox_entry.dart';
import '../inbox/notification_inbox_store.dart';
import '../providers/notification_retry_preferences.dart';

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
  static const maxRetries = 2;
  static const _maxTreatmentRetries = 3;
  final Future<bool> Function() retriesEnabled;
  final Future<void> Function(NotificationEvent)? showSystemRetry;
  final Future<void> Function(NotificationEvent, int, int)? showInAppRetry;

  /// Null means relevance could not be verified and should be checked again.
  final Future<bool?> Function(NotificationEvent)? retryStillRelevant;
  final Future<void> Function(
    NotificationInboxEntry,
    FamilyChatNotificationEvent,
    Future<void> Function(),
  )?
  withAuthorizedChatRetry;
  bool _processingRetries = false;

  NotificationsControllerImpl(
    this._ref,
    this._inAppController, {
    required this._localController,
    this.onShown,
    this.isAppVisible,
    this.onInboxChanged,
    NotificationInboxStore? inbox,
    this.retriesEnabled = readNotificationRetriesEnabled,
    this.showSystemRetry,
    this.showInAppRetry,
    this.retryStillRelevant,
    this.withAuthorizedChatRetry,
  }) : _inbox = inbox ?? NotificationInboxStore();

  @override
  Future<void> init() async {
    await _localController.init();
    await _inAppController.init();
  }

  Future<bool> _shouldPresentInApp(NotificationEvent event) async {
    if (isActionableFamilyTreatment(event) ||
        !NotificationDefinitionCatalogImpl().byType(event.type).presentInApp) {
      return false;
    }
    if (_ref.read(appLifecycleProvider) != AppLifecycleState.resumed) {
      return false;
    }
    final probe = isAppVisible;
    if (probe == null) return true;
    try {
      return await probe() &&
          _ref.read(appLifecycleProvider) == AppLifecycleState.resumed;
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
      if (event is FamilyChatNotificationEvent && event.transient) {
        await (inApp ? _inAppController : _localController).show(event);
        return;
      }
      // Record before handing the event over: the UI re-shows unread in-app
      // entries from the inbox, so a banner message lost between isolates
      // still reaches the user.
      final now = clock.now();
      final stored = await _inbox.put(
        NotificationInboxEntry.fromEvent(
          event,
          id: notificationIdentity(event).id,
          createdAt: now,
          inApp: inApp,
          retryAt: await _firstRetryAt(event, now),
          retriesRemaining: isActionableFamilyTreatment(event)
              ? _maxTreatmentRetries
              : maxRetries,
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
    final due = clock.now().add(duration);
    await _inbox.put(
      NotificationInboxEntry.fromEvent(
        event,
        id: notificationIdentity(event).id,
        createdAt: due,
        retryAt: await _firstRetryAt(event, due),
        retriesRemaining: isActionableFamilyTreatment(event)
            ? _maxTreatmentRetries
            : maxRetries,
      ),
    );
    // Lets the UI arm its refresh for when the entry becomes due.
    onInboxChanged?.call();
  }

  Future<DateTime?> _firstRetryAt(NotificationEvent event, DateTime due) async {
    if (notificationRetryPolicy(event) == NotificationRetryPolicy.none) {
      return null;
    }
    return await _retriesEnabled()
        ? due.add(notificationRetryDelayFor(event))
        : null;
  }

  Future<bool> _retriesEnabled() async {
    try {
      return await retriesEnabled();
    } catch (error) {
      Log.w('NotificationsController', 'Retry setting unavailable ($error)');
      return false;
    }
  }

  /// Runs in the foreground service, the single owner of due retries.
  Future<void> processDueRetries() async {
    if (_processingRetries) return;
    _processingRetries = true;
    try {
      final now = clock.now();
      for (final entry in await _inbox.retriesDue(now)) {
        try {
          final event = NotificationEventFactory().fromPayload(
            entry.type,
            entry.data,
          );
          final policy = notificationRetryPolicy(event);
          final eligible =
              await _retriesEnabled() &&
              policy != NotificationRetryPolicy.none &&
              !(policy == NotificationRetryPolicy.untilRead && entry.read);
          final check = retryStillRelevant;
          final relevant = eligible && check != null
              ? await check(event)
              : eligible;
          if (relevant != true) {
            await _inbox.advanceRetry(
              entry,
              nextDue: relevant == null
                  ? clock.now().add(notificationRetryDelayFor(event))
                  : now,
              remaining: relevant == null ? entry.retriesRemaining : 0,
              inApp: entry.inApp,
              resetRead: false,
            );
            continue;
          }
          if (event is FamilyChatNotificationEvent) {
            await withAuthorizedChatRetry?.call(
              entry,
              event,
              () => _retry(entry, event, policy),
            );
          } else {
            await _retry(entry, event, policy);
          }
        } catch (error) {
          Log.w('NotificationsController', 'Retry ${entry.id} failed ($error)');
        }
      }
    } finally {
      _processingRetries = false;
    }
  }

  Future<void> _retry(
    NotificationInboxEntry entry,
    NotificationEvent event,
    NotificationRetryPolicy policy,
  ) async {
    final inApp = await _shouldPresentInApp(event);
    final latest = await _inbox.get(entry.id);
    if (latest == null ||
        !latest.active ||
        latest.createdAt != entry.createdAt ||
        (policy == NotificationRetryPolicy.untilRead && latest.read)) {
      return;
    }
    final leaseUntil = clock.now().add(const Duration(seconds: 30));
    final claim = leaseUntil.millisecondsSinceEpoch;
    if (!await _inbox.advanceRetry(
      entry,
      nextDue: entry.retryAt!,
      remaining: entry.retriesRemaining,
      inApp: entry.inApp,
      resetRead: inApp && policy == NotificationRetryPolicy.untilAnswered,
      leaseUntil: leaseUntil,
      notify: false,
    )) {
      return;
    }
    final current = await _inbox.get(entry.id);
    if (current == null ||
        !current.active ||
        current.createdAt != entry.createdAt ||
        current.retryClaim != claim ||
        (policy == NotificationRetryPolicy.untilRead && current.read)) {
      return;
    }
    try {
      if (inApp) {
        final deliver = showInAppRetry;
        if (deliver != null) {
          // The UI acknowledges the claim after presenting the banner or
          // successfully handing it off to Android.
          await deliver(event, entry.createdAt.millisecondsSinceEpoch, claim);
          return;
        }
        await _inAppController.show(event);
      } else {
        await (showSystemRetry ?? _localController.show)(event);
      }
    } catch (_) {
      await _inbox.advanceRetry(
        current,
        nextDue: entry.retryAt!,
        remaining: entry.retriesRemaining,
        inApp: entry.inApp,
        resetRead: false,
        notify: false,
      );
      rethrow;
    }
    // A crash between presentation and acknowledgement can repeat the same
    // OS identity after the lease expires instead of silently losing a try.
    await _inbox.advanceRetry(
      current,
      nextDue: clock.now().add(notificationRetryDelayFor(event)),
      remaining: entry.retriesRemaining - 1,
      inApp: inApp,
      resetRead: false,
      retryDelivery: true,
    );
    if (!inApp) {
      final after = await _inbox.get(entry.id);
      if (after != null &&
          after.createdAt == entry.createdAt &&
          (!after.active ||
              (policy == NotificationRetryPolicy.untilRead && after.read))) {
        final identity = notificationIdentity(event);
        await _localController.cancel(identity.id, tag: identity.tag);
      }
      onInboxChanged?.call();
    }
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    await _inbox.cancel(id);
    await _localController.cancel(id, tag: tag);
    await _guardInApp(() => _inAppController.cancel(id, tag: tag));
  }

  @override
  Future<void> cancelAll() async {
    await _inbox.cancelAll();
    await _localController.cancelAll();
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
