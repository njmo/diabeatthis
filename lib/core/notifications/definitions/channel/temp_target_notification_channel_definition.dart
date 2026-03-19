import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notifications_channel_definition.dart';

const targetNotificationChannelDefinition = NotificationChannelDefinition(
  type: NotificationChannelType.target,
  id: 'temp_target_channel_v2',
  name: 'Temp Target Notifications',
  description: 'Proposal to set temp target',
  importance: Importance.max,
);
