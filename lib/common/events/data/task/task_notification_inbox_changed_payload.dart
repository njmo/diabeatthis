import '../../task_event_payload.dart';

/// Tells the UI isolate that the foreground service changed the notification
/// inbox, and which in-app banners are no longer valid.
class TaskNotificationInboxChangedPayload with TaskEventPayload {
  const TaskNotificationInboxChangedPayload({
    this.dismissedIds = const [],
    this.dismissAll = false,
  });

  final List<int> dismissedIds;
  final bool dismissAll;

  factory TaskNotificationInboxChangedPayload.fromJson(
    Map<String, dynamic> json,
  ) => TaskNotificationInboxChangedPayload(
    dismissedIds: (json['dismissedIds'] as List<dynamic>? ?? const [])
        .whereType<int>()
        .toList(),
    dismissAll: json['dismissAll'] as bool? ?? false,
  );

  @override
  String get eventName => 'task_notification_inbox_changed';

  @override
  Map<String, dynamic> toJson() => {
    'dismissedIds': dismissedIds,
    'dismissAll': dismissAll,
  };
}
