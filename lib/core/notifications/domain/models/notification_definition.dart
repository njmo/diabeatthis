import 'notification_action_def.dart';
import 'notification_channel_type.dart';
import 'notification_event_type.dart';

class NotificationDefinition {
  final NotificationEventType type;
  final String categoryId;
  final List<NotificationActionDef> actions;
  final NotificationChannelType channelType;

  /// Whether the notification may be shown as an in-app banner while the app
  /// is in the foreground. Notifications meant to stay visible after the user
  /// leaves the app (e.g. instructions to follow in another app) opt out.
  final bool presentInApp;

  const NotificationDefinition({
    required this.type,
    required this.categoryId,
    required this.actions,
    required this.channelType,
    this.presentInApp = true,
  });
}
