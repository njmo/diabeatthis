import '../domain/models/notification_event.dart';
import '../domain/models/notification_event_type.dart';

/// A durable mirror of one notification, readable from every isolate.
///
/// [data] is the event's `toJson()` so the original [NotificationEvent] can be
/// rebuilt with `NotificationEventFactory` to answer its actions later.
class NotificationInboxEntry {
  const NotificationInboxEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.read = false,
    this.active = true,
    this.inApp = false,
  });

  factory NotificationInboxEntry.fromEvent(
    NotificationEvent event, {
    required int id,
    required DateTime createdAt,
    bool inApp = false,
  }) => NotificationInboxEntry(
    id: id,
    type: event.type,
    title: event.title,
    body: event.body,
    data: Map<String, dynamic>.from(event.toJson()),
    createdAt: createdAt,
    inApp: inApp,
  );

  final int id;
  final NotificationEventType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  /// The user has seen it, either as a banner or in the inbox.
  final bool read;

  /// Its actions can still be answered. Cancelled or answered entries stay in
  /// the history but no longer offer buttons.
  final bool active;

  /// Delivered as an in-app banner rather than a system notification. Unread
  /// in-app entries are re-shown as banners until the user handles them, so a
  /// banner lost between isolates still reaches the user.
  final bool inApp;

  NotificationInboxEntry copyWith({bool? read, bool? active}) =>
      NotificationInboxEntry(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        createdAt: createdAt,
        read: read ?? this.read,
        active: active ?? this.active,
        inApp: inApp,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'data': data,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'read': read,
    'active': active,
    'inApp': inApp,
  };

  static NotificationInboxEntry? tryParse(Map<String, dynamic> json) {
    try {
      final typeName = json['type'] as String;
      final type = NotificationEventType.values.firstWhere(
        (value) => value.name == typeName,
      );
      return NotificationInboxEntry(
        id: json['id'] as int,
        type: type,
        title: json['title'] as String,
        body: json['body'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int,
        ),
        read: json['read'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
        inApp: json['inApp'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}
