import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notifications_channel_definition.dart';

const activityNotificationChannelDefinition = NotificationChannelDefinition(
  type: NotificationChannelType.activity,
  id: 'activity_monitor_channel_v1',
  name: 'Activity Monitor Notifications',
  description: 'Reminders about monitored activities',
  importance: Importance.max,
);
