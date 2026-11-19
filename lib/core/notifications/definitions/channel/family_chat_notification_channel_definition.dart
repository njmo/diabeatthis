import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notifications_channel_definition.dart';

const familyChatNotificationChannelDefinition = NotificationChannelDefinition(
  type: NotificationChannelType.familyChat,
  id: 'family_chat_messages',
  name: 'Rozmowy rodzinne',
  description: 'Powiadomienia o wiadomościach rodzinnych',
  importance: Importance.high,
);
