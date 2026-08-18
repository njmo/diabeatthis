import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_channel_type.dart';

class NotificationChannelDefinition {
  const NotificationChannelDefinition({
    required this.type,
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
  });

  final NotificationChannelType type;
  final String id;
  final String name;
  final String description;
  final Importance importance;
}
