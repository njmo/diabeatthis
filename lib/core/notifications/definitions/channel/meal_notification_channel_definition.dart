import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notifications_channel_definition.dart';

const mealNotificationChannelDefinition = NotificationChannelDefinition(
  type: NotificationChannelType.meal,
  id: 'meal_wait_channel_v2',
  name: 'Meal Wait Notifications',
  description: 'Reminders that you can start eating',
  importance: Importance.max,
);
