import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notifications_channel_definition.dart';

NotificationChannelDefinition get mealNotificationChannelDefinition =>
    NotificationChannelDefinition(
      type: NotificationChannelType.meal,
      id: 'meal_wait_channel_v2',
      name: lang.notificationChannelMealName,
      description: lang.notificationChannelMealDescription,
      importance: Importance.max,
    );
