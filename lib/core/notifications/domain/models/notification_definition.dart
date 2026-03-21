import 'notification_action_def.dart';
import 'notification_channel_type.dart';
import 'notification_event_type.dart';

class NotificationDefinition {
  final NotificationEventType type;
  final String categoryId;
  final List<NotificationActionDef> actions;
  final NotificationChannelType channelType;

  const NotificationDefinition({
    required this.type,
    required this.categoryId,
    required this.actions,
    required this.channelType,
  });
}