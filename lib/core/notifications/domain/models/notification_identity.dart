import '../events/family_chat_notification.dart';
import 'hash_notification_id_factory.dart';
import 'notification_event.dart';

/// The Android identity of a notification: its id and optional tag.
typedef NotificationIdentity = ({int id, String? tag});

const _idFactory = HashNotificationIdFactory();

/// Most notifications derive a stable id from their key. Chat notifications
/// carry the id and tag assigned by the durable family chat journal, which
/// must be kept so the right Android notification is replaced or withdrawn.
NotificationIdentity notificationIdentity(NotificationEvent event) =>
    switch (event) {
      FamilyChatNotificationEvent(:final id, :final tag) => (
        id: id,
        tag: tag.isEmpty ? null : tag,
      ),
      _ => (id: _idFactory.create(event.key), tag: null),
    };
