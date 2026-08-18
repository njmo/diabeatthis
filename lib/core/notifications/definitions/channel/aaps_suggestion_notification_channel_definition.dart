import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notifications_channel_definition.dart';

const aapsSuggestionNotificationChannelDefinition =
    NotificationChannelDefinition(
      type: NotificationChannelType.aapsSuggestion,
      id: 'aaps_suggestion_channel_v1',
      name: 'AAPS Suggestions',
      description: 'Suggestions visible after opening AAPS',
      importance: Importance.max,
    );
