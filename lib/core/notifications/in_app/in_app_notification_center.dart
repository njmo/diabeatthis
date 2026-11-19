import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../common/family_chat/notifications/family_chat_presenter_provider.dart';
import '../../logger/logger.dart';
import '../controllers/local_notifications_controller.dart';
import '../definitions/notification_definition_catalog_impl.dart';
import '../domain/events/family_chat_notification.dart';
import '../domain/events/notification_event_factory.dart';
import '../domain/models/notification_action_def.dart';
import '../domain/models/notification_action_type.dart';
import '../domain/models/notification_definition.dart';
import '../domain/models/notification_event.dart';
import '../domain/models/notification_event_actions.dart';
import '../domain/models/notification_identity.dart';
import '../handlers/notification_response_handler.dart';
import '../inbox/notification_inbox_entry.dart';
import '../inbox/notification_inbox_store.dart';
import '../providers/local_notifications_controller_provider.dart';

/// One notification currently queued as an in-app banner.
class InAppBanner {
  const InAppBanner({
    required this.id,
    required this.event,
    required this.definition,
  });

  final int id;
  final NotificationEvent event;
  final NotificationDefinition definition;

  /// The buttons this delivery offers, as on the system notification.
  List<NotificationActionDef> get actions =>
      notificationActionsFor(event, definition);

  /// Suggested answers for a text action.
  List<String> get inputChoices => notificationInputChoicesFor(event);

  /// Tapping a chat message opens its conversation.
  bool get opensOnTap =>
      event is FamilyChatNotificationEvent && actions.isNotEmpty;
}

class InAppNotificationState {
  const InAppNotificationState({
    this.banners = const [],
    this.inbox = const [],
  });

  /// Banner queue; the first one is on screen.
  final List<InAppBanner> banners;

  /// Notification history, newest first.
  final List<NotificationInboxEntry> inbox;

  InAppBanner? get current => banners.isEmpty ? null : banners.first;
  int get unreadCount => inbox.where((entry) => !entry.read).length;

  InAppNotificationState copyWith({
    List<InAppBanner>? banners,
    List<NotificationInboxEntry>? inbox,
  }) => InAppNotificationState(
    banners: banners ?? this.banners,
    inbox: inbox ?? this.inbox,
  );
}

final notificationInboxStoreProvider = Provider<NotificationInboxStore>(
  (_) => NotificationInboxStore(),
);

final inAppNotificationResponderProvider = Provider(
  (_) => respondToNotification,
);

final inAppNotificationCenterProvider =
    NotifierProvider<InAppNotificationCenter, InAppNotificationState>(
      InAppNotificationCenter.new,
    );

/// UI-isolate owner of in-app banners and the notification inbox.
///
/// The inbox is the source of truth: every unread, still-active entry that
/// was routed in-app is shown as a banner while the app is visible. Messages
/// from the service only speed this up, so a message lost while the UI was
/// starting still surfaces on the next refresh.
class InAppNotificationCenter extends Notifier<InAppNotificationState>
    with Logging {
  final _catalog = NotificationDefinitionCatalogImpl();
  int _refreshGeneration = 0;
  bool _refreshQueued = false;
  Timer? _dueTimer;

  /// Banners the user or the app already took down in this session; a refresh
  /// that raced with persisting that decision must not bring them back.
  final _suppressed = <int>{};

  NotificationInboxStore get _store => ref.read(notificationInboxStoreProvider);

  LocalNotificationsController get _local =>
      ref.read(localNotificationsControllerProvider);

  @override
  InAppNotificationState build() {
    ref.listen(appLifecycleProvider, (_, next) {
      switch (next) {
        case AppLifecycleState.resumed:
          unawaited(refresh());
        case AppLifecycleState.hidden:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
          unawaited(_handOverBannersToSystem());
        case AppLifecycleState.inactive:
          break;
      }
    });
    // Push handlers and responses may change the inbox from their own
    // containers; follow along so withdrawn notifications leave the screen.
    final changes = NotificationInboxStore.changes.listen(
      (_) => _queueRefresh(),
    );
    ref.onDispose(() {
      _dueTimer?.cancel();
      unawaited(changes.cancel());
    });
    Future.microtask(refresh);
    return const InAppNotificationState();
  }

  bool get _isVisible =>
      ref.read(appLifecycleProvider) == AppLifecycleState.resumed;

  /// Shows [event] as a banner, or as a system notification when the app is
  /// no longer visible by the time the event arrives.
  Future<void> present(NotificationEvent event) async {
    if (!_isVisible) {
      await _local.show(event);
      await refresh();
      return;
    }
    final id = notificationIdentity(event).id;
    // The service records a delivery before announcing it. If the user already
    // handled that delivery through a banner restored from the inbox, a late
    // announcement must not bring it back.
    final recorded = await _store.get(id);
    if (recorded != null && (recorded.read || !recorded.active)) {
      await refresh();
      return;
    }
    _suppressed.remove(id);
    _pushBanner(
      InAppBanner(
        id: id,
        event: event,
        definition: _catalog.byType(event.type),
      ),
    );
    await refresh();
  }

  /// The user closed the banner. The notification stays in the inbox and its
  /// actions can still be answered from there.
  Future<void> dismiss(int id) async {
    _takeDown(id);
    await _store.markRead([id]);
    await refresh();
  }

  /// The notification was withdrawn by the app.
  Future<void> cancel(int id) async {
    _takeDown(id);
    await refresh();
  }

  Future<void> cancelAll() async {
    _suppressed.addAll(state.banners.map((banner) => banner.id));
    state = state.copyWith(banners: const []);
    await refresh();
  }

  /// Answers [action] exactly like the matching system notification button.
  Future<void> respond({
    required int id,
    required NotificationEvent event,
    required NotificationActionDef action,
    String? input,
  }) async {
    _takeDown(id);
    // Resolve first: the answer may post a follow-up status under the same
    // id (e.g. "reply sent"), which must not be resolved away afterwards.
    await _store.resolve(id);
    // A copy may have been posted to the system tray meanwhile.
    await _withdrawSystemCopy(event);
    await _answer(id, event, action.type.toDarwinString(), input);
    await refresh();
  }

  /// The user tapped the banner itself, like tapping the system notification.
  Future<void> open(int id, NotificationEvent event) async {
    _takeDown(id);
    await _store.markRead([id]);
    await _answer(id, event, null, null);
    await refresh();
  }

  Future<void> _answer(
    int id,
    NotificationEvent event,
    String? actionId,
    String? input,
  ) async {
    try {
      await ref.read(inAppNotificationResponderProvider)(
        payload: jsonEncode({
          ...event.toPayload(),
          notificationIdPayloadKey: id,
        }),
        actionId: actionId,
        input: input,
        familyChatPresenter: event is FamilyChatNotificationEvent
            ? ref.read(familyChatUiPresenterProvider)
            : null,
      );
    } catch (_) {
      logW('Could not answer notification $id');
    }
  }

  /// Rebuilds the event behind an inbox entry so its actions can be answered.
  NotificationEvent? eventFor(NotificationInboxEntry entry) {
    try {
      return const NotificationEventFactory().fromPayload(
        entry.type,
        entry.data,
      );
    } catch (error) {
      logW('Could not restore notification ${entry.id} ($error)');
      return null;
    }
  }

  NotificationDefinition definitionFor(NotificationInboxEntry entry) =>
      _catalog.byType(entry.type);

  Future<void> markAllRead() async {
    final unread = state.inbox.where((entry) => !entry.read).map((e) => e.id);
    if (unread.isEmpty) return;
    await _store.markRead(unread.toList());
    await refresh();
  }

  Future<void> clear() async {
    await _store.clear();
    await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    final inbox = await _store.visible();
    final nextDue = await _store.nextDueAt();
    // A newer refresh may have started meanwhile; keep the latest snapshot.
    if (generation != _refreshGeneration) return;
    state = state.copyWith(inbox: inbox, banners: _reconcile(inbox));
    _scheduleDueRefresh(nextDue);
  }

  /// Drops banners whose notification is no longer pending and restores
  /// pending in-app entries that have no banner (e.g. their message was lost).
  List<InAppBanner> _reconcile(List<NotificationInboxEntry> inbox) {
    final byId = {for (final entry in inbox) entry.id: entry};
    final banners = state.banners.where((banner) {
      final entry = byId[banner.id];
      // Not persisted yet (or storage unavailable): keep what was presented.
      // Answered, withdrawn or already seen in the inbox: take it down.
      return entry == null || (entry.active && !entry.read);
    }).toList();
    if (!_isVisible) return banners;
    final shown = banners.map((banner) => banner.id).toSet();
    // The inbox is newest first; restored banners go behind live ones.
    for (final entry in inbox) {
      if (!entry.inApp ||
          entry.read ||
          !entry.active ||
          shown.contains(entry.id) ||
          _suppressed.contains(entry.id)) {
        continue;
      }
      final event = eventFor(entry);
      if (event == null) continue;
      banners.add(
        InAppBanner(
          id: entry.id,
          event: event,
          definition: definitionFor(entry),
        ),
      );
      // It may have been handed to the system tray while the app was in the
      // background; the banner replaces that copy.
      unawaited(_withdrawSystemCopy(event));
    }
    return banners;
  }

  Future<void> _withdrawSystemCopy(NotificationEvent event) async {
    final identity = notificationIdentity(event);
    try {
      await _local.cancel(identity.id, tag: identity.tag);
    } catch (error) {
      logW('Could not withdraw system notification ${identity.id} ($error)');
    }
  }

  void _queueRefresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    scheduleMicrotask(() {
      _refreshQueued = false;
      unawaited(refresh());
    });
  }

  void _scheduleDueRefresh(DateTime? nextDue) {
    _dueTimer?.cancel();
    _dueTimer = null;
    if (nextDue == null) return;
    var delay = nextDue.difference(clock.now());
    if (delay.isNegative) delay = Duration.zero;
    _dueTimer = Timer(delay + const Duration(seconds: 1), () {
      unawaited(refresh());
    });
  }

  /// Newest first, so a fresh notification is never hidden behind an older,
  /// unanswered one.
  void _pushBanner(InAppBanner banner) {
    state = state.copyWith(
      banners: [banner, ...state.banners.where((item) => item.id != banner.id)],
    );
  }

  void _takeDown(int id) {
    _suppressed.add(id);
    if (state.banners.every((banner) => banner.id != id)) return;
    state = state.copyWith(
      banners: state.banners.where((banner) => banner.id != id).toList(),
    );
  }

  /// Banners that still expect an answer must not vanish when the user leaves
  /// the app, so they are re-posted as system notifications.
  Future<void> _handOverBannersToSystem() async {
    final pending = state.banners;
    if (pending.isEmpty) return;
    state = state.copyWith(banners: const []);
    for (final banner in pending) {
      if (banner.actions.isEmpty) continue;
      try {
        // Skip anything answered or withdrawn meanwhile, and withdraw again
        // if that happened while the system notification was being posted.
        if ((await _store.get(banner.id))?.active == false) continue;
        await _local.show(banner.event);
        if ((await _store.get(banner.id))?.active == false) {
          await _withdrawSystemCopy(banner.event);
        }
      } catch (error, stackTrace) {
        logE(
          'Could not hand banner ${banner.id} over to the system',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
